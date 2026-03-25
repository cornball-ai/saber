#' @title Project briefings
#' @description Generate project context for AI coding agents.

#' Generate a project briefing
#'
#' Produces a concise markdown briefing combining DESCRIPTION metadata,
#' downstream dependents, 'Claude Code' memory, and recent git commits.
#' Written to the user cache directory so both the agent and user
#' see the same context.
#'
#' @param project Project name. If NULL, inferred from the current working
#'   directory basename.
#' @param scan_dir Directory to scan for project directories.
#' @param memory_base Base directory for Claude Code project memory files.
#' @param briefs_dir Directory to write briefing markdown files.
#' @param max_memory_lines Maximum lines to include from the memory file.
#' @return A character string of class \code{saber_briefing}. Printing the
#'   object emits the markdown briefing. Also written to
#'   \code{briefs_dir/{project}.md}.
#' @examples
#' d <- file.path(tempdir(), "briefpkg")
#' dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
#' writeLines(c("Package: briefpkg", "Title: Demo", "Version: 0.1.0"),
#'            file.path(d, "DESCRIPTION"))
#' briefing("briefpkg", scan_dir = tempdir(),
#'          briefs_dir = file.path(tempdir(), "briefs"))
#' @export
briefing <- function(project = NULL, scan_dir = path.expand("~"),
                     memory_base = file.path(path.expand("~"), ".claude", "projects"),
                     briefs_dir = file.path(tools::R_user_dir("saber", "cache"), "briefs"),
                     max_memory_lines = 30L) {
    if (is.null(project)) {
        project <- basename(getwd())
    }
    dir.create(briefs_dir, recursive = TRUE, showWarnings = FALSE)

    lines <- character(0L)
    lines <- c(lines, sprintf("# Briefing: %s", project))
    lines <- c(lines,
               sprintf("_Generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M")))
    lines <- c(lines, "")

    desc <- briefing_desc(project, scan_dir)
    if (length(desc) > 0L) {
        lines <- c(lines, desc, "")
    }

    ds <- briefing_downstream(project, scan_dir)
    if (length(ds) > 0L) {
        lines <- c(lines, ds, "")
    }

    mem <- briefing_memory(project, memory_base, max_memory_lines)
    if (length(mem) > 0L) {
        lines <- c(lines, mem, "")
    }

    git <- briefing_git(project, scan_dir)
    if (length(git) > 0L) {
        lines <- c(lines, git, "")
    }

    outfile <- file.path(briefs_dir, paste0(project, ".md"))
    writeLines(lines, outfile)

    structure(
        paste(lines, collapse = "\n"),
        class = c("saber_briefing", "character"),
        file = outfile,
        project = project
    )
}

#' @export
#' @noRd
print.saber_briefing <- function(x, ...) {
    cat(unclass(x), "\n", sep = "")
    invisible(x)
}

#' DESCRIPTION metadata section
#' @noRd
briefing_desc <- function(project, scan_dir) {
    repo_dir <- file.path(scan_dir, project)
    desc_file <- file.path(repo_dir, "DESCRIPTION")
    if (!file.exists(desc_file)) {
        return(character(0L))
    }

    dcf <- tryCatch(
                    read.dcf(desc_file,
                             fields = c("Package", "Title", "Version", "Imports")),
                    error = function(e) NULL
    )
    if (is.null(dcf) || nrow(dcf) == 0L) {
        return(character(0L))
    }

    lines <- "## Package"
    pkg <- dcf[1L, "Package"]
    if (!is.na(pkg)) {
        lines <- c(lines, sprintf("- **Name**: %s", pkg))
    }

    title <- dcf[1L, "Title"]
    if (!is.na(title)) {
        lines <- c(lines, sprintf("- **Title**: %s", title))
    }

    ver <- dcf[1L, "Version"]
    if (!is.na(ver)) {
        lines <- c(lines, sprintf("- **Version**: %s", ver))
    }

    imports <- dcf[1L, "Imports"]
    if (!is.na(imports) && nchar(trimws(imports)) > 0L) {
        lines <- c(lines, sprintf("- **Imports**: %s", trimws(imports)))
    }

    if (length(lines) == 1L) {
        return(character(0L))
    }
    lines
}

#' Downstream dependents section
#' @noRd
briefing_downstream <- function(project, scan_dir) {
    ds <- find_downstream(project, scan_dir)
    if (length(ds) == 0L) {
        return(character(0L))
    }

    lines <- "## Downstream dependents"
    for (d in ds) {
        lines <- c(lines, sprintf("- %s", d))
    }
    lines
}

#' 'Claude Code' memory section
#' @noRd
briefing_memory <- function(project, memory_base, max_lines) {
    if (is.null(memory_base) || !dir.exists(memory_base)) {
        return(character(0L))
    }

    mem_dirs <- list.dirs(memory_base, recursive = FALSE, full.names = TRUE)
    mem_file <- NULL
    for (md in mem_dirs) {
        proj_encoded <- basename(md)
        proj_name <- sub("^.*-home-[^-]+-", "", proj_encoded)
        if (proj_name == project) {
            candidate <- file.path(md, "memory", "MEMORY.md")
            if (file.exists(candidate)) {
                mem_file <- candidate
                break
            }
        }
    }

    if (is.null(mem_file)) {
        return(character(0L))
    }

    mem_lines <- readLines(mem_file, warn = FALSE)
    lines <- "## Memory"
    if (length(mem_lines) > max_lines) {
        lines <- c(lines, mem_lines[seq_len(max_lines)],
                   sprintf("_... truncated (%d more lines)_",
                           length(mem_lines) - max_lines))
    } else {
        lines <- c(lines, mem_lines)
    }
    lines
}

#' Recent git activity section
#' @noRd
briefing_git <- function(project, scan_dir) {
    repo_dir <- file.path(scan_dir, project)
    if (!dir.exists(file.path(repo_dir, ".git"))) {
        return(character(0L))
    }

    log <- tryCatch(
                    system2("git", c("-C", repo_dir, "log", "--oneline", "-5"),
                            stdout = TRUE, stderr = FALSE),
                    error = function(e) character(0L)
    )
    if (length(log) == 0L) {
        return(character(0L))
    }

    lines <- "## Recent commits"
    for (l in log) {
        lines <- c(lines, sprintf("- %s", l))
    }
    lines
}
