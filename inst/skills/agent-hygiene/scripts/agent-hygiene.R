#!/usr/bin/env Rscript
# agent-hygiene.R: audit and reconcile agent instruction files and skill roots.
#
# Usage:
#   Rscript agent-hygiene.R audit [--manifest PATH] [--project DIR]
#   Rscript agent-hygiene.R link  [--manifest PATH] [--dry-run]
#   Rscript agent-hygiene.R list  [--manifest PATH] [--html FILE]
#
# The manifest is a DCF file read from --manifest, $AGENTS_SKILLS_DCF, or
# ~/.config/agents/skills.dcf:
#
#   Hub: ~/skills
#   Packages: ~/saber, ~/pensar
#   AgentRoots: ~/.claude/skills, ~/.agents/skills
#
# audit is read-only and exits 1 when it reports drift. list prints every
# skill (active, archived, unlinked, dangling) and can write an HTML table.
# link only creates or repairs symlinks: package-owned skills into the hub,
# and each agent root onto the hub. It never removes a real file or
# directory, and it refuses names two packages both provide. Requires saber
# 0.7.2.5 or later for skill_manifest(). jsonlite is optional; it enables the
# corteza config and Claude plugin sections.

hygiene_split <- function(x) {
    if (is.null(x) || length(x) != 1L || is.na(x)) {
        return(character())
    }
    x <- trimws(strsplit(x, ",", fixed = TRUE)[[1L]])
    x[nzchar(x)]
}

hygiene_path <- function(x) {
    normalizePath(path.expand(x), winslash = "/", mustWork = FALSE)
}

hygiene_is_link <- function(path) {
    link <- Sys.readlink(path)
    !is.na(link) && nzchar(link)
}

hygiene_manifest_path <- function(path = NULL) {
    if (!is.null(path)) {
        return(path.expand(path))
    }
    env <- Sys.getenv("AGENTS_SKILLS_DCF", unset = "")
    if (nzchar(env)) {
        return(path.expand(env))
    }
    path.expand("~/.config/agents/skills.dcf")
}

hygiene_manifest <- function(path) {
    if (!file.exists(path)) {
        stop("Manifest not found: ", path, call. = FALSE)
    }
    dcf <- read.dcf(path)
    if (nrow(dcf) != 1L) {
        stop("Manifest must hold exactly one record.", call. = FALSE)
    }
    field <- function(key) {
        if (key %in% colnames(dcf)) dcf[1L, key] else NA_character_
    }
    hub <- field("Hub")
    if (is.na(hub) || !nzchar(trimws(hub))) {
        stop("Manifest needs a Hub field.", call. = FALSE)
    }
    list(hub = path.expand(trimws(hub)),
         packages = path.expand(hygiene_split(field("Packages"))),
         agent_roots = path.expand(hygiene_split(field("AgentRoots"))),
         path = path)
}

# Frontmatter name and description, including folded blocks;
# saber::skill_manifest() is the full parser.
hygiene_frontmatter <- function(skill_md) {
    out <- list(name = NA_character_, description = NA_character_)
    lines <- tryCatch(readLines(skill_md, n = 200L, warn = FALSE),
                      error = function(e) character())
    if (!length(lines)) {
        return(out)
    }
    first <- utf8ToInt(enc2utf8(lines[[1L]]))
    first <- first[first != 0xFEFFL]
    if (!identical(intToUtf8(first), "---")) {
        return(out)
    }
    body <- lines[-1L]
    end <- which(trimws(body) == "---")
    if (!length(end)) {
        return(out)
    }
    yaml <- body[seq_len(end[[1L]] - 1L)]
    for (key in c("name", "description")) {
        hit <- grep(paste0("^", key, ":[[:blank:]]*"), yaml)
        if (!length(hit)) {
            next
        }
        value <- sub(paste0("^", key, ":[[:blank:]]*"), "", yaml[[hit[[1L]]]])
        if (grepl("^[>|][+-]?$", value)) {
            i <- hit[[1L]] + 1L
            block <- character()
            while (i <= length(yaml) && grepl("^([[:blank:]]|$)", yaml[[i]])) {
                block <- c(block, trimws(yaml[[i]]))
                i <- i + 1L
            }
            value <- paste(block[nzchar(block)], collapse = " ")
        }
        out[[key]] <- trimws(gsub("^[\"']|[\"']$", "", value))
    }
    out
}

hygiene_frontmatter_name <- function(skill_md) {
    hygiene_frontmatter(skill_md)$name
}

hygiene_package_skills <- function(packages) {
    empty <- data.frame(name = character(), path = character(),
                        package = character(), root = character(),
                        stringsAsFactors = FALSE)
    if (!length(packages)) {
        return(empty)
    }
    missing <- packages[!file.exists(file.path(packages, "DESCRIPTION"))]
    if (length(missing)) {
        stop("Not a package checkout: ", paste(missing, collapse = ", "),
             call. = FALSE)
    }
    if (!requireNamespace("saber", quietly = TRUE) ||
        utils::packageVersion("saber") < "0.7.2.5") {
        stop("saber 0.7.2.5 or later is required for skill_manifest().",
             call. = FALSE)
    }
    m <- saber::skill_manifest(packages = character(), lib.loc = character(),
                               project_dirs = packages)
    e <- m$entries[m$entries$selected, , drop = FALSE]
    out <- data.frame(name = e$name, path = hygiene_path(e$path),
                      package = e$package, root = hygiene_path(e$root),
                      stringsAsFactors = FALSE)
    attr(out, "diagnostics") <- m$diagnostics
    out
}

hygiene_hub_entries <- function(hub, package_skills) {
    empty <- data.frame(entry = character(), kind = character(),
                        real = character(), name = character(),
                        stringsAsFactors = FALSE)
    if (!dir.exists(hub)) {
        stop("Hub directory not found: ", hub, call. = FALSE)
    }
    rows <- list()
    for (entry in sort(list.files(hub, all.files = TRUE, no.. = TRUE))) {
        path <- file.path(hub, entry)
        is_link <- hygiene_is_link(path)
        if (!is_link && !dir.exists(path)) {
            next
        }
        real <- hygiene_path(path)
        has_skill <- file.exists(file.path(path, "SKILL.md"))
        kind <- if (is_link && !file.exists(path)) {
            "dangling"
        } else if (!has_skill) {
            if (is_link) "link-no-skill" else "other"
        } else if (is_link && real %in% package_skills$path) {
            "package"
        } else if (is_link) {
            "foreign-link"
        } else {
            "local"
        }
        name <- if (has_skill) {
            hygiene_frontmatter_name(file.path(path, "SKILL.md"))
        } else {
            NA_character_
        }
        rows[[length(rows) + 1L]] <- data.frame(entry = entry, kind = kind,
            real = real, name = name, stringsAsFactors = FALSE)
    }
    do.call(rbind, c(list(empty), rows))
}

hygiene_agent_roots <- function(roots, hub) {
    hub_real <- hygiene_path(hub)
    rows <- lapply(roots, function(root) {
        is_link <- hygiene_is_link(root)
        status <- if (!is_link && !file.exists(root)) {
            "missing"
        } else if (is_link && identical(hygiene_path(root), hub_real)) {
            "hub"
        } else if (is_link) {
            "other-link"
        } else {
            "directory"
        }
        data.frame(root = root, status = status, stringsAsFactors = FALSE)
    })
    do.call(rbind, c(list(data.frame(root = character(), status = character(),
                                     stringsAsFactors = FALSE)), rows))
}

hygiene_instruction_files <- function(project_dir = getwd()) {
    claude_dir <- Sys.getenv("CLAUDE_CONFIG_DIR", unset = "~/.claude")
    codex_dir <- Sys.getenv("CODEX_HOME", unset = "~/.codex")
    shared <- Sys.getenv("AGENTS_GLOBAL_MD", unset = "~/.config/agents/GLOBAL.md")
    paths <- path.expand(c(shared, file.path(claude_dir, "CLAUDE.md"),
                           file.path(codex_dir, "AGENTS.md")))
    global <- data.frame(role = c("shared", "claude", "codex"), path = paths,
                         exists = file.exists(paths),
                         real = hygiene_path(paths), stringsAsFactors = FALSE)
    agents <- file.path(project_dir, "AGENTS.md")
    claude <- file.path(project_dir, "CLAUDE.md")
    project <- list(agents = file.exists(agents), claude = file.exists(claude),
                    same_file = FALSE, same_content = FALSE)
    if (project$agents && project$claude) {
        project$same_file <- identical(hygiene_path(agents), hygiene_path(claude))
        sums <- tools::md5sum(c(agents, claude))
        project$same_content <- identical(unname(sums[[1L]]), unname(sums[[2L]]))
    }
    list(global = global, project = project)
}

# corteza 0.7.1.47 and later accept a top-level symlink alias inside a
# configured root, so the hub alone can be the root. Older versions refuse
# the package links and need each package's inst/skills listed instead.
hygiene_corteza_roots <- function(hub, package_skills) {
    config <- file.path(tools::R_user_dir("corteza", "config"), "config.json")
    if (!file.exists(config) || !requireNamespace("jsonlite", quietly = TRUE)) {
        return(NULL)
    }
    roots <- tryCatch(jsonlite::fromJSON(config, simplifyVector = FALSE)$instruction_roots,
                      error = function(e) NULL)
    configured <- character()
    if (length(roots)) {
        configured <- hygiene_path(unlist(roots, use.names = FALSE))
    }
    findings <- character()
    hub_real <- hygiene_path(hub)
    if (hub_real %in% configured) {
        version <- tryCatch(utils::packageVersion("corteza"), error = function(e) NULL)
        if (!is.null(version) && version < "0.7.1.47") {
            findings <- sprintf(
                "corteza %s refuses symlink aliases in an instruction root; upgrade to 0.7.1.47 or list each package's inst/skills root instead of the hub.",
                as.character(version))
        }
        return(list(config = config, configured = configured, expected = hub_real,
                    findings = findings))
    }
    expected <- unique(package_skills$root)
    for (root in expected) {
        if (root %in% configured) {
            next
        }
        inside <- configured[startsWith(configured, paste0(root, "/"))]
        if (length(inside)) {
            findings <- c(findings, sprintf(
                "corteza root %s points inside %s; list the whole inst/skills root so every skill of the package is found.",
                inside[[1L]], root))
        } else {
            findings <- c(findings, sprintf(
                "corteza instruction_roots lacks %s.", root))
        }
    }
    list(config = config, configured = configured, expected = expected,
         findings = findings)
}

# Skills a Claude plugin delivers: its marketplace entry, else skills/, else
# every SKILL.md under the install path.
hygiene_plugin_skill_names <- function(root, plugin) {
    name <- sub("@.*$", "", plugin)
    manifest <- file.path(root, ".claude-plugin", "marketplace.json")
    if (file.exists(manifest)) {
        m <- tryCatch(jsonlite::fromJSON(manifest, simplifyVector = FALSE),
                      error = function(e) NULL)
        for (p in m$plugins %||% list()) {
            if (identical(p$name, name)) {
                return(basename(unlist(p$skills, use.names = FALSE)))
            }
        }
    }
    default <- file.path(root, "skills")
    if (dir.exists(default)) {
        return(list.dirs(default, recursive = FALSE, full.names = FALSE))
    }
    found <- list.files(root, pattern = "^SKILL\\.md$", recursive = TRUE,
                        full.names = TRUE)
    basename(dirname(found))
}

hygiene_claude_plugins <- function(hub_names) {
    claude_dir <- path.expand(Sys.getenv("CLAUDE_CONFIG_DIR", unset = "~/.claude"))
    installed <- file.path(claude_dir, "plugins", "installed_plugins.json")
    if (!file.exists(installed) || !requireNamespace("jsonlite", quietly = TRUE)) {
        return(NULL)
    }
    plugins <- tryCatch(jsonlite::fromJSON(installed, simplifyVector = FALSE)$plugins,
                        error = function(e) NULL)
    findings <- character()
    for (plugin in names(plugins %||% list())) {
        for (install in plugins[[plugin]]) {
            root <- install$installPath
            if (is.null(root) || !dir.exists(root)) {
                next
            }
            dup <- intersect(hygiene_plugin_skill_names(root, plugin), hub_names)
            if (length(dup)) {
                findings <- c(findings, sprintf(
                    "Claude plugin %s also delivers hub skills: %s.",
                    plugin, paste(sort(dup), collapse = ", ")))
            }
        }
    }
    findings
}

`%||%` <- function(x, y) if (is.null(x)) y else x

hygiene_say <- function(quiet, ...) {
    if (!quiet) {
        cat(..., "\n", sep = "")
    }
}

hygiene_audit <- function(manifest, project_dir = getwd(), quiet = FALSE) {
    out <- list()

    files <- hygiene_instruction_files(project_dir)
    findings <- character()
    hygiene_say(quiet, "## Instruction files")
    present <- files$global[files$global$exists, , drop = FALSE]
    for (i in seq_len(nrow(files$global))) {
        row <- files$global[i, ]
        hygiene_say(quiet, sprintf("  %-7s %s%s", row$role, row$path,
                                   if (row$exists) paste0(" -> ", row$real) else "  (missing)"))
    }
    if (nrow(present) > 1L && length(unique(present$real)) > 1L) {
        findings <- c(findings, "Global instruction names resolve to more than one file.")
    }
    absent <- files$global[!files$global$exists, , drop = FALSE]
    if (nrow(absent)) {
        findings <- c(findings, sprintf(
            "%s instruction file %s is missing; link it to the shared file.",
            absent$role, absent$path))
    }
    p <- files$project
    if (p$agents && p$claude) {
        if (p$same_file) {
            hygiene_say(quiet, "  project AGENTS.md and CLAUDE.md are one file")
        } else if (p$same_content) {
            findings <- c(findings, "Project AGENTS.md and CLAUDE.md are separate files with identical content; link one to the other so they cannot drift.")
        } else {
            findings <- c(findings, "Project AGENTS.md and CLAUDE.md differ; corteza loads both, Claude Code and Codex each load their own.")
        }
    } else {
        hygiene_say(quiet, sprintf("  project: AGENTS.md %s, CLAUDE.md %s",
                                   if (p$agents) "present" else "absent",
                                   if (p$claude) "present" else "absent"))
    }
    out$instructions <- findings

    package_skills <- hygiene_package_skills(manifest$packages)
    entries <- hygiene_hub_entries(manifest$hub, package_skills)
    findings <- character()
    hygiene_say(quiet, "## Hub ", manifest$hub)
    skills <- entries[entries$kind %in% c("local", "package", "foreign-link", "dangling"), , drop = FALSE]
    for (i in seq_len(nrow(skills))) {
        row <- skills[i, ]
        hygiene_say(quiet, sprintf("  %-12s %s%s", row$kind, row$entry,
                                   if (row$kind %in% c("package", "foreign-link")) paste0(" -> ", row$real) else ""))
    }
    diagnostics <- attr(package_skills, "diagnostics")
    if (!is.null(diagnostics) && nrow(diagnostics)) {
        findings <- c(findings, sprintf("skill_manifest could not read %s: %s",
                                        diagnostics$path, diagnostics$reason))
    }
    dangling <- skills$entry[skills$kind == "dangling"]
    if (length(dangling)) {
        findings <- c(findings, sprintf("Dangling hub link: %s", dangling))
    }
    mismatch <- skills[!is.na(skills$name) & skills$name != skills$entry, , drop = FALSE]
    if (nrow(mismatch)) {
        findings <- c(findings, sprintf("Hub entry %s has frontmatter name %s.",
                                        mismatch$entry, mismatch$name))
    }
    noname <- skills$entry[skills$kind != "dangling" & is.na(skills$name)]
    if (length(noname)) {
        findings <- c(findings, sprintf("Hub entry %s has no frontmatter name.", noname))
    }
    dup <- unique(skills$name[!is.na(skills$name) & duplicated(skills$name)])
    if (length(dup)) {
        findings <- c(findings, sprintf("Skill name %s appears more than once in the hub.", dup))
    }
    unlinked <- package_skills[!package_skills$path %in% skills$real, , drop = FALSE]
    if (nrow(unlinked)) {
        findings <- c(findings, sprintf("Package skill %s (%s) is not linked into the hub.",
                                        unlinked$name, unlinked$package))
    }
    foreign <- skills$entry[skills$kind == "foreign-link"]
    if (length(foreign)) {
        findings <- c(findings, sprintf("Hub link %s points outside the manifest's packages.", foreign))
    }
    # Claude Code writes claude.ai-synced skills to <skills root>/synced; with
    # the root linked to the hub that lands here, where Codex recurses into it.
    synced <- file.path(manifest$hub, "synced")
    if (dir.exists(synced)) {
        found <- list.files(synced, pattern = "^SKILL\\.md$", recursive = TRUE)
        findings <- c(findings, sprintf(
            "claude.ai-synced skills live under %s (%s); Claude Code loads them natively and Codex recurses into them. Review or remove them.",
            synced,
            if (length(found)) paste(sort(basename(dirname(found))), collapse = ", ") else "no SKILL.md yet"))
    }
    out$hub <- findings

    roots <- hygiene_agent_roots(manifest$agent_roots, manifest$hub)
    findings <- character()
    hygiene_say(quiet, "## Agent roots")
    hub_names <- skills$entry[skills$kind != "dangling"]
    for (i in seq_len(nrow(roots))) {
        row <- roots[i, ]
        hygiene_say(quiet, sprintf("  %-10s %s", row$status, row$root))
        if (row$status == "hub") {
            next
        }
        if (row$status == "directory") {
            have <- list.files(row$root, all.files = TRUE, no.. = TRUE)
            findings <- c(findings, sprintf(
                "%s is a directory, not a link to the hub (missing here: %s; extra here: %s).",
                row$root,
                paste(setdiff(hub_names, have), collapse = ", "),
                paste(setdiff(have, hub_names), collapse = ", ")))
        } else {
            findings <- c(findings, sprintf("%s is %s; expected a link to the hub.",
                                            row$root, row$status))
        }
    }
    out$agent_roots <- findings

    corteza <- hygiene_corteza_roots(manifest$hub, package_skills)
    if (!is.null(corteza)) {
        hygiene_say(quiet, "## corteza ", corteza$config)
        for (root in corteza$configured) {
            hygiene_say(quiet, "  root ", root)
        }
        out$corteza <- corteza$findings
    }

    plugins <- hygiene_claude_plugins(hub_names)
    if (!is.null(plugins)) {
        hygiene_say(quiet, "## Claude plugins")
        out$plugins <- plugins
    }

    all <- unlist(out, use.names = FALSE)
    hygiene_say(quiet, "## Findings: ", length(all))
    for (line in all) {
        hygiene_say(quiet, "  !! ", line)
    }
    invisible(out)
}

# Plan every link first, then apply. A name provided by two packages, a
# symlink that points somewhere the manifest does not know, or a real
# directory in the way is a conflict and is left untouched. Only a missing
# entry, a dangling link, or a link to another manifest package is changed.
hygiene_link <- function(manifest, dry_run = FALSE, quiet = FALSE) {
    if (!dir.exists(manifest$hub)) {
        stop("Hub directory not found: ", manifest$hub, call. = FALSE)
    }
    package_skills <- hygiene_package_skills(manifest$packages)
    changes <- character()
    conflicts <- character()

    dup <- unique(package_skills$name[duplicated(package_skills$name)])
    for (name in dup) {
        owners <- sort(unique(package_skills$package[package_skills$name == name]))
        conflicts <- c(conflicts, sprintf(
            "Skill %s is provided by more than one package (%s); nothing linked for it.",
            name, paste(owners, collapse = ", ")))
    }
    package_skills <- package_skills[!package_skills$name %in% dup, , drop = FALSE]
    known <- hygiene_path(package_skills$path)

    plan <- list()
    consider <- function(target, path, what, relinkable) {
        target <- hygiene_path(target)
        if (hygiene_is_link(path)) {
            current <- hygiene_path(path)
            if (identical(current, target)) {
                return(invisible())
            }
            if (file.exists(path) && !current %in% relinkable) {
                conflicts <<- c(conflicts, sprintf(
                    "%s %s links to %s, which the manifest does not know; move it aside before linking.",
                    what, path, current))
                return(invisible())
            }
            plan[[length(plan) + 1L]] <<- list(action = "relink", target = target,
                                               path = path, what = what)
        } else if (file.exists(path)) {
            conflicts <<- c(conflicts, sprintf(
                "%s %s exists and is not a symlink; move it aside before linking.",
                what, path))
        } else {
            plan[[length(plan) + 1L]] <<- list(action = "link", target = target,
                                               path = path, what = what)
        }
        invisible()
    }
    for (i in seq_len(nrow(package_skills))) {
        consider(package_skills$path[i], file.path(manifest$hub, package_skills$name[i]),
                 "package skill", known)
    }
    for (root in manifest$agent_roots) {
        consider(manifest$hub, root, "agent root", character())
    }

    for (step in plan) {
        line <- sprintf("%s %s %s -> %s", step$action, step$what, step$path, step$target)
        if (dry_run) {
            changes <- c(changes, line)
            next
        }
        if (step$action == "relink") {
            unlink(step$path)
        }
        dir.create(dirname(step$path), recursive = TRUE, showWarnings = FALSE)
        made <- suppressWarnings(file.symlink(step$target, step$path))
        if (isTRUE(made) && identical(hygiene_path(step$path), step$target)) {
            changes <- c(changes, line)
        } else {
            conflicts <- c(conflicts, sprintf("Could not create %s %s -> %s.",
                                              step$what, step$path, step$target))
        }
    }
    hygiene_say(quiet, if (dry_run) "## Would change" else "## Changed")
    for (line in changes) hygiene_say(quiet, "  ", line)
    if (!length(changes)) hygiene_say(quiet, "  nothing")
    for (line in conflicts) hygiene_say(quiet, "  !! ", line)
    invisible(list(changes = changes, conflicts = conflicts))
}

# Every skill the owner has: hub entries, archived ones, and package skills
# that are not linked yet.
hygiene_skill_rows <- function(manifest) {
    package_skills <- hygiene_package_skills(manifest$packages)
    entries <- hygiene_hub_entries(manifest$hub, package_skills)
    rows <- list()
    add <- function(status, name, owner, path) {
        skill_md <- file.path(path, "SKILL.md")
        description <- if (file.exists(skill_md)) {
            hygiene_frontmatter(skill_md)$description
        } else {
            NA_character_
        }
        rows[[length(rows) + 1L]] <<- data.frame(
            status = status, name = name, owner = owner, path = path,
            description = description, stringsAsFactors = FALSE)
    }
    for (i in seq_len(nrow(entries))) {
        e <- entries[i, ]
        if (e$kind == "local") {
            add("active", e$entry, "hub", file.path(manifest$hub, e$entry))
        } else if (e$kind == "package") {
            add("active", e$entry,
                package_skills$package[match(e$real, package_skills$path)], e$real)
        } else if (e$kind == "foreign-link") {
            add("active", e$entry, "link", e$real)
        } else if (e$kind == "dangling") {
            add("dangling", e$entry, "link", e$real)
        }
    }
    archive <- file.path(manifest$hub, ".archive")
    if (dir.exists(archive)) {
        for (d in sort(list.dirs(archive, recursive = FALSE, full.names = FALSE))) {
            if (file.exists(file.path(archive, d, "SKILL.md"))) {
                add("archived", d, "archive", file.path(archive, d))
            }
        }
    }
    linked <- entries$real[entries$kind == "package"]
    for (i in seq_len(nrow(package_skills))) {
        if (!package_skills$path[i] %in% linked) {
            add("unlinked", package_skills$name[i], package_skills$package[i],
                package_skills$path[i])
        }
    }
    empty <- data.frame(status = character(), name = character(),
                        owner = character(), path = character(),
                        description = character(), stringsAsFactors = FALSE)
    out <- do.call(rbind, c(list(empty), rows))
    out[order(match(out$status, c("active", "unlinked", "dangling", "archived")),
              out$name), , drop = FALSE]
}

hygiene_html_escape <- function(x) {
    x <- gsub("&", "&amp;", x, fixed = TRUE)
    x <- gsub("<", "&lt;", x, fixed = TRUE)
    gsub(">", "&gt;", x, fixed = TRUE)
}

hygiene_html <- function(rows, roots, manifest) {
    counts <- table(factor(rows$status,
                           levels = c("active", "archived", "unlinked", "dangling")))
    cell <- function(x) paste0("<td>", hygiene_html_escape(x), "</td>")
    body <- vapply(seq_len(nrow(rows)), function(i) {
        description <- rows$description[i]
        if (is.na(description)) description <- ""
        paste0("<tr class=\"", rows$status[i], "\">",
               cell(rows$status[i]), cell(rows$name[i]), cell(rows$owner[i]),
               cell(rows$path[i]), cell(description), "</tr>")
    }, character(1L))
    c("<!doctype html>", "<meta charset=\"utf-8\">",
      "<meta name=\"viewport\" content=\"width=device-width\">",
      "<title>Skills</title>",
      paste0("<style>body{font:14px system-ui,sans-serif;margin:2em;color:#222}",
             "table{border-collapse:collapse}td,th{border:1px solid #ccc;",
             "padding:4px 8px;vertical-align:top;text-align:left}",
             "tr.archived{color:#777}tr.dangling,tr.unlinked{background:#fee}",
             "</style>"),
      sprintf("<h1>Skills in %s</h1>", hygiene_html_escape(manifest$hub)),
      sprintf("<p>%d active, %d archived, %d unlinked, %d dangling. Generated %s.</p>",
              counts[["active"]], counts[["archived"]], counts[["unlinked"]],
              counts[["dangling"]], format(Sys.time(), "%Y-%m-%d %H:%M")),
      paste0("<p>Agent roots: ",
             paste(sprintf("%s (%s)", hygiene_html_escape(roots$root), roots$status),
                   collapse = ", "), "</p>"),
      "<table><tr><th>status</th><th>name</th><th>owner</th><th>path</th><th>description</th></tr>",
      body, "</table>")
}

hygiene_list <- function(manifest, html = NULL, quiet = FALSE) {
    rows <- hygiene_skill_rows(manifest)
    roots <- hygiene_agent_roots(manifest$agent_roots, manifest$hub)
    if (!quiet) {
        name_w <- max(nchar(c("name", rows$name)))
        owner_w <- max(nchar(c("owner", rows$owner)))
        cat(sprintf("%-9s %-*s %-*s %s\n", "status", name_w, "name", owner_w, "owner",
                    "description"))
        for (i in seq_len(nrow(rows))) {
            description <- rows$description[i]
            if (is.na(description)) description <- ""
            if (nchar(description) > 72L) {
                description <- paste0(substr(description, 1L, 69L), "...")
            }
            cat(sprintf("%-9s %-*s %-*s %s\n", rows$status[i], name_w, rows$name[i],
                        owner_w, rows$owner[i], description))
        }
        counts <- table(factor(rows$status,
                               levels = c("active", "archived", "unlinked", "dangling")))
        cat(sprintf("\n%d active, %d archived, %d unlinked, %d dangling. Agent roots: %s\n",
                    counts[["active"]], counts[["archived"]], counts[["unlinked"]],
                    counts[["dangling"]],
                    paste(sprintf("%s (%s)", roots$root, roots$status), collapse = ", ")))
    }
    if (!is.null(html)) {
        writeLines(hygiene_html(rows, roots, manifest), html)
        hygiene_say(quiet, "Wrote ", html)
    }
    invisible(rows)
}

hygiene_args <- function(args) {
    if (length(args) == 0L && exists("argv", envir = globalenv(), inherits = FALSE)) {
        littler <- get("argv", envir = globalenv(), inherits = FALSE)
        if (is.character(littler)) {
            args <- littler
        }
    }
    opts <- list(command = NA_character_, manifest = NULL, project = getwd(),
                 dry_run = FALSE, html = NULL)
    i <- 1L
    while (i <= length(args)) {
        arg <- args[[i]]
        if (arg == "--dry-run") {
            opts$dry_run <- TRUE
        } else if (arg %in% c("--manifest", "--project", "--html")) {
            if (i == length(args)) {
                stop(arg, " needs a value.", call. = FALSE)
            }
            opts[[sub("^--", "", arg)]] <- args[[i + 1L]]
            i <- i + 1L
        } else if (is.na(opts$command) && !startsWith(arg, "--")) {
            opts$command <- arg
        } else {
            stop("Unknown argument: ", arg, call. = FALSE)
        }
        i <- i + 1L
    }
    opts
}

hygiene_main <- function(args) {
    opts <- hygiene_args(args)
    if (is.na(opts$command) || !opts$command %in% c("audit", "link", "list")) {
        cat("Usage: agent-hygiene.R audit [--manifest PATH] [--project DIR]\n",
            "       agent-hygiene.R link  [--manifest PATH] [--dry-run]\n",
            "       agent-hygiene.R list  [--manifest PATH] [--html FILE]\n", sep = "")
        quit(status = 2L)
    }
    manifest <- hygiene_manifest(hygiene_manifest_path(opts$manifest))
    if (opts$command == "audit") {
        findings <- hygiene_audit(manifest, project_dir = path.expand(opts$project))
        quit(status = if (length(unlist(findings))) 1L else 0L)
    }
    if (opts$command == "list") {
        html <- if (is.null(opts$html)) NULL else path.expand(opts$html)
        hygiene_list(manifest, html = html)
        quit(status = 0L)
    }
    result <- hygiene_link(manifest, dry_run = opts$dry_run)
    quit(status = if (length(result$conflicts)) 1L else 0L)
}

if (sys.nframe() == 0L) {
    hygiene_main(commandArgs(trailingOnly = TRUE))
}
