#' @title Project briefings
#' @description Generate project context for AI coding agents.

#' Generate a project briefing
#'
#' Produces a concise markdown briefing combining DESCRIPTION metadata,
#' downstream dependents, and recent git commits. Written to the user
#' cache directory so both the agent and user see the same context.
#'
#' For runtime context (memory, identity files, project instructions),
#' see \code{\link{agent_context}}.
#'
#' @param project Project name. If NULL, inferred from the current working
#'   directory basename.
#' @param scan_dir Directory to scan for project directories.
#' @param briefs_dir Directory to write briefing markdown files.
#' @return The briefing text (character string), returned invisibly. Emitted
#'   via \code{message()} and written to \code{briefs_dir/{project}.md}.
#' @examples
#' d <- file.path(tempdir(), "briefpkg")
#' dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
#' writeLines(c("Package: briefpkg", "Title: Demo", "Version: 0.1.0"),
#'            file.path(d, "DESCRIPTION"))
#' briefing("briefpkg", scan_dir = tempdir(),
#'          briefs_dir = file.path(tempdir(), "briefs"))
#' @export
briefing <- function(project = NULL, scan_dir = path.expand("~"),
                     briefs_dir = file.path(tools::R_user_dir("saber", "cache"), "briefs")) {
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

    git <- briefing_git(project, scan_dir)
    if (length(git) > 0L) {
        lines <- c(lines, git, "")
    }

    text <- paste(lines, collapse = "\n")

    outfile <- file.path(briefs_dir, paste0(project, ".md"))
    writeLines(lines, outfile)

    message(text)
    invisible(text)
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

