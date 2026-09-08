# Exercise the agent-hygiene script against a temporary layout.

if (.Platform$OS.type == "windows") {
    exit_file("agent-hygiene link uses POSIX symlinks.")
}
if (!exists("skill_manifest", envir = asNamespace("saber"), inherits = FALSE)) {
    exit_file("Installed saber predates skill_manifest().")
}

script <- system.file("skills", "agent-hygiene", "scripts", "agent-hygiene.R",
                      package = "saber")
if (!nzchar(script)) {
    script <- file.path("..", "skills", "agent-hygiene", "scripts", "agent-hygiene.R")
}
if (!file.exists(script)) {
    exit_file("agent-hygiene.R not found.")
}

hygiene <- new.env()
sys.source(script, envir = hygiene)

root <- tempfile("hygiene-")
dir.create(root)
pkg <- file.path(root, "pkgalpha")
dir.create(file.path(pkg, "inst", "skills", "alpha"), recursive = TRUE)
writeLines(c("Package: pkgalpha", "Version: 0.0.1"), file.path(pkg, "DESCRIPTION"))
writeLines(c("---", "name: alpha", "description: Alpha skill.", "---", "Body."),
           file.path(pkg, "inst", "skills", "alpha", "SKILL.md"))
hub <- file.path(root, "hub")
dir.create(file.path(hub, "beta"), recursive = TRUE)
writeLines(c("---", "name: beta", "description: Beta skill.", "---", "Body."),
           file.path(hub, "beta", "SKILL.md"))
dir.create(file.path(hub, ".archive", "old"), recursive = TRUE)
writeLines(c("---", "name: old", "description: Retired.", "---"),
           file.path(hub, ".archive", "old", "SKILL.md"))
roots <- file.path(root, c("claude-skills", "agents-skills"))
manifest_path <- file.path(root, "skills.dcf")
writeLines(c(paste0("Hub: ", hub), paste0("Packages: ", pkg),
             paste0("AgentRoots: ", paste(roots, collapse = ", "))),
           manifest_path)

manifest <- hygiene$hygiene_manifest(manifest_path)
expect_equal(manifest$hub, hub)
expect_equal(manifest$packages, pkg)
expect_equal(manifest$agent_roots, roots)

# Missing package checkout is an error, not a silent skip.
expect_error(hygiene$hygiene_package_skills(file.path(root, "nope")),
             "Not a package checkout")

# Dry run reports and changes nothing.
dry <- hygiene$hygiene_link(manifest, dry_run = TRUE, quiet = TRUE)
expect_equal(length(dry$changes), 3L)
expect_false(file.exists(file.path(hub, "alpha")))
expect_false(file.exists(roots[[1L]]))

# Link creates the package link and the agent roots.
done <- hygiene$hygiene_link(manifest, quiet = TRUE)
expect_equal(length(done$changes), 3L)
expect_equal(length(done$conflicts), 0L)
expect_equal(normalizePath(file.path(hub, "alpha")),
             normalizePath(file.path(pkg, "inst", "skills", "alpha")))
expect_equal(normalizePath(roots[[1L]]), normalizePath(hub))
expect_equal(normalizePath(roots[[2L]]), normalizePath(hub))

# A second run is idempotent.
again <- hygiene$hygiene_link(manifest, quiet = TRUE)
expect_equal(length(again$changes), 0L)

entries <- hygiene$hygiene_hub_entries(hub, hygiene$hygiene_package_skills(pkg))
expect_equal(entries$kind[entries$entry == "alpha"], "package")
expect_equal(entries$kind[entries$entry == "beta"], "local")
expect_equal(entries$kind[entries$entry == ".archive"], "other")

audit <- hygiene$hygiene_audit(manifest, project_dir = root, quiet = TRUE)
expect_equal(length(audit$hub), 0L)
expect_equal(length(audit$agent_roots), 0L)

# A real directory in the way is a conflict, never replaced.
unlink(roots[[1L]])
dir.create(roots[[1L]])
writeLines("keep", file.path(roots[[1L]], "keep.txt"))
blocked <- hygiene$hygiene_link(manifest, quiet = TRUE)
expect_equal(length(blocked$conflicts), 1L)
expect_true(file.exists(file.path(roots[[1L]], "keep.txt")))
audit <- hygiene$hygiene_audit(manifest, project_dir = root, quiet = TRUE)
expect_equal(length(audit$agent_roots), 1L)
expect_true(grepl("is a directory", audit$agent_roots[[1L]]))

# Frontmatter drift and dangling links are findings.
writeLines(c("---", "name: gamma", "description: Beta skill.", "---"),
           file.path(hub, "beta", "SKILL.md"))
file.symlink(file.path(root, "gone"), file.path(hub, "delta"))
audit <- hygiene$hygiene_audit(manifest, project_dir = root, quiet = TRUE)
expect_true(any(grepl("frontmatter name gamma", audit$hub)))
expect_true(any(grepl("Dangling hub link: delta", audit$hub)))

# corteza roots: the hub alone is enough on 0.7.1.47+, otherwise each
# package's inst/skills root must be listed.
if (requireNamespace("jsonlite", quietly = TRUE)) {
    old_config <- Sys.getenv("R_USER_CONFIG_DIR", unset = NA_character_)
    Sys.setenv(R_USER_CONFIG_DIR = file.path(root, "config-home"))
    config <- file.path(tools::R_user_dir("corteza", "config"), "config.json")
    dir.create(dirname(config), recursive = TRUE, showWarnings = FALSE)
    pkg_skills <- hygiene$hygiene_package_skills(pkg)
    corteza_version <- tryCatch(packageVersion("corteza"), error = function(e) NULL)

    writeLines(sprintf('{"instruction_roots": {"skills": "%s"}}', hub), config)
    via_hub <- hygiene$hygiene_corteza_roots(hub, pkg_skills)
    if (!is.null(corteza_version) && corteza_version < "0.7.1.47") {
        expect_true(any(grepl("upgrade to 0.7.1.47", via_hub$findings)))
    } else {
        expect_equal(length(via_hub$findings), 0L)
    }

    writeLines(sprintf('{"instruction_roots": {"pkgalpha": "%s"}}',
                       file.path(pkg, "inst", "skills")), config)
    via_pkg <- hygiene$hygiene_corteza_roots(hub, pkg_skills)
    expect_equal(length(via_pkg$findings), 0L)

    writeLines(sprintf('{"instruction_roots": {"pkgalpha": "%s"}}',
                       file.path(pkg, "inst", "skills", "alpha")), config)
    narrow <- hygiene$hygiene_corteza_roots(hub, pkg_skills)
    expect_true(any(grepl("points inside", narrow$findings)))

    writeLines('{}', config)
    none <- hygiene$hygiene_corteza_roots(hub, pkg_skills)
    expect_true(any(grepl("lacks", none$findings)))

    if (is.na(old_config)) {
        Sys.unsetenv("R_USER_CONFIG_DIR")
    } else {
        Sys.setenv(R_USER_CONFIG_DIR = old_config)
    }
}

# Argument parsing.
opts <- hygiene$hygiene_args(c("link", "--dry-run", "--manifest", manifest_path))
expect_equal(opts$command, "link")
expect_true(opts$dry_run)
expect_equal(opts$manifest, manifest_path)
expect_error(hygiene$hygiene_args(c("audit", "--bogus")), "Unknown argument")
expect_equal(hygiene$hygiene_args(c("list", "--html", "x.html"))$html, "x.html")

# Folded descriptions are read whole.
writeLines(c("---", "name: folded", "description: >", "  First line", "  second line.",
             "---", "Body."), file.path(root, "folded.md"))
expect_equal(hygiene$hygiene_frontmatter(file.path(root, "folded.md"))$description,
             "First line second line.")

# Instruction files: a missing global name and separate-but-identical project
# files are findings, not a clean report.
old_env <- Sys.getenv(c("CLAUDE_CONFIG_DIR", "CODEX_HOME", "AGENTS_GLOBAL_MD"),
                      unset = NA_character_)
shared <- file.path(root, "agents", "GLOBAL.md")
dir.create(dirname(shared), recursive = TRUE)
writeLines("shared body", shared)
Sys.setenv(CLAUDE_CONFIG_DIR = file.path(root, "claude-home"),
           CODEX_HOME = file.path(root, "codex-home"),
           AGENTS_GLOBAL_MD = shared)
only_shared <- hygiene$hygiene_audit(manifest, project_dir = root, quiet = TRUE)
expect_equal(sum(grepl("is missing", only_shared$instructions)), 2L)
dir.create(file.path(root, "claude-home"))
dir.create(file.path(root, "codex-home"))
file.symlink(shared, file.path(root, "claude-home", "CLAUDE.md"))
file.symlink(shared, file.path(root, "codex-home", "AGENTS.md"))
linked <- hygiene$hygiene_audit(manifest, project_dir = root, quiet = TRUE)
expect_equal(length(linked$instructions), 0L)
project <- file.path(root, "project")
dir.create(project)
writeLines("same", file.path(project, "CLAUDE.md"))
writeLines("same", file.path(project, "AGENTS.md"))
twins <- hygiene$hygiene_audit(manifest, project_dir = project, quiet = TRUE)
expect_true(any(grepl("identical content", twins$instructions)))
writeLines("different", file.path(project, "AGENTS.md"))
split <- hygiene$hygiene_audit(manifest, project_dir = project, quiet = TRUE)
expect_true(any(grepl("differ;", split$instructions)))
unlink(file.path(project, "AGENTS.md"))
file.symlink("CLAUDE.md", file.path(project, "AGENTS.md"))
one <- hygiene$hygiene_audit(manifest, project_dir = project, quiet = TRUE)
expect_equal(length(one$instructions), 0L)
for (key in names(old_env)) {
    if (is.na(old_env[[key]])) {
        Sys.unsetenv(key)
    } else {
        do.call(Sys.setenv, as.list(old_env[key]))
    }
}

# Two packages providing one name: a conflict, and the existing link stays.
pkg_beta <- file.path(root, "pkgbeta")
dir.create(file.path(pkg_beta, "inst", "skills", "alpha"), recursive = TRUE)
writeLines(c("Package: pkgbeta", "Version: 0.0.1"), file.path(pkg_beta, "DESCRIPTION"))
writeLines(c("---", "name: alpha", "description: Rival alpha.", "---"),
           file.path(pkg_beta, "inst", "skills", "alpha", "SKILL.md"))
two <- manifest
two$packages <- c(pkg, pkg_beta)
clash <- hygiene$hygiene_link(two, quiet = TRUE)
expect_true(any(grepl("more than one package", clash$conflicts)))
expect_equal(normalizePath(file.path(hub, "alpha")),
             normalizePath(file.path(pkg, "inst", "skills", "alpha")))

# A hub link to a directory the manifest does not know is a conflict, not a
# silent relink; a dangling link is repaired.
elsewhere <- file.path(root, "elsewhere", "alpha")
dir.create(elsewhere, recursive = TRUE)
writeLines(c("---", "name: alpha", "description: Stray.", "---"),
           file.path(elsewhere, "SKILL.md"))
unlink(file.path(hub, "alpha"))
file.symlink(elsewhere, file.path(hub, "alpha"))
stray <- hygiene$hygiene_link(manifest, quiet = TRUE)
expect_true(any(grepl("does not know", stray$conflicts)))
expect_equal(normalizePath(file.path(hub, "alpha")), normalizePath(elsewhere))
unlink(file.path(hub, "alpha"))
file.symlink(file.path(root, "gone"), file.path(hub, "alpha"))
repaired <- hygiene$hygiene_link(manifest, quiet = TRUE)
# The only conflict left is the real directory sitting at the first agent root.
expect_false(any(grepl("alpha", repaired$conflicts, fixed = TRUE)))
expect_true(any(grepl("relink package skill", repaired$changes, fixed = TRUE)))
expect_equal(normalizePath(file.path(hub, "alpha")),
             normalizePath(file.path(pkg, "inst", "skills", "alpha")))

# claude.ai-synced skills inside the hub are reported.
dir.create(file.path(hub, "synced", "cloud"), recursive = TRUE)
writeLines(c("---", "name: cloud", "description: Synced.", "---"),
           file.path(hub, "synced", "cloud", "SKILL.md"))
synced <- hygiene$hygiene_audit(manifest, project_dir = root, quiet = TRUE)
expect_true(any(grepl("synced skills live under .*cloud", synced$hub)))

# list covers active, archived, and dangling entries and writes HTML.
rows <- hygiene$hygiene_list(manifest, html = file.path(root, "skills.html"),
                             quiet = TRUE)
expect_equal(rows$status[rows$name == "alpha"], "active")
expect_equal(rows$owner[rows$name == "alpha"], "pkgalpha")
expect_equal(rows$status[rows$name == "old"], "archived")
expect_equal(rows$status[rows$name == "delta"], "dangling")
expect_equal(rows$description[rows$name == "alpha"], "Alpha skill.")
html <- readLines(file.path(root, "skills.html"))
expect_true(any(grepl("<td>alpha</td>", html, fixed = TRUE)))
expect_true(any(grepl("<td>old</td>", html, fixed = TRUE)))

unlink(root, recursive = TRUE)
