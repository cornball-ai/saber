#' @title Cross-project activity heartbeat
#' @description Summarize recent git activity across every repository
#'   under a directory.

#' Summarize recent git activity across projects
#'
#' Scans every git repository directly under \code{scan_dir}, counts
#' commits inside the lookback window, and produces a markdown summary of
#' the active projects with their most recent commits, busiest first. The
#' complement to \code{\link{briefing}}: \code{briefing()} is one project
#' in depth, \code{heartbeat()} is every project at a glance.
#'
#' @param days Integer. Lookback window in days.
#' @param scan_dir Directory whose immediate subdirectories are scanned.
#' @param n Integer. Maximum commits to list per active project.
#' @param exclude Character vector of directory basenames to skip.
#' @param briefs_dir Directory to write the heartbeat markdown file.
#' @return The heartbeat text (character string), returned invisibly.
#'   Emitted via \code{message()} and written to
#'   \code{briefs_dir/_heartbeat.md}.
#' @examples
#' root <- file.path(tempdir(), "hbscan")
#' dir.create(root, showWarnings = FALSE)
#' heartbeat(days = 7, scan_dir = root,
#'           briefs_dir = file.path(tempdir(), "briefs"))
#' @export
heartbeat <- function(days = 7L, scan_dir = path.expand("~"), n = 5L,
                      exclude = default_exclude(),
                      briefs_dir = file.path(tools::R_user_dir("saber", "cache"), "briefs")) {
    dirs <- list.dirs(scan_dir, recursive = FALSE)
    dirs <- dirs[!basename(dirs) %in% exclude]
    since <- Sys.Date() - days

    active <- list()
    for (d in dirs) {
        cnt <- git_commit_count_since(d, since)
        if (cnt < 1L) {
            next
        }
        active[[basename(d)]] <- list(count = cnt,
                                      log = git_log_since(d, since, n))
    }

    lines <- character(0L)
    lines <- c(lines, sprintf("# Heartbeat: last %d day(s)", as.integer(days)))
    lines <- c(lines,
               sprintf("_Generated %s_", format(Sys.time(), "%Y-%m-%d %H:%M")))
    lines <- c(lines, "")

    if (length(active) == 0L) {
        lines <- c(lines, "No commits in the window.")
    } else {
        counts <- vapply(active, function(a) a$count, integer(1))
        for (nm in names(active)[order(-counts, names(active))]) {
            a <- active[[nm]]
            lines <- c(lines,
                       sprintf("## %s (%d commit%s)", nm, a$count,
                    if (a$count == 1L) "" else "s"))
            if (length(a$log) > 0L) {
                lines <- c(lines, sprintf("- %s", a$log))
            }
            lines <- c(lines, "")
        }
    }

    text <- paste(lines, collapse = "\n")

    dir.create(briefs_dir, recursive = TRUE, showWarnings = FALSE)
    writeLines(lines, file.path(briefs_dir, "_heartbeat.md"))

    message(text)
    invisible(text)
}

#' Count commits since a date, or 0 for non-repos
#'
#' rev-parse confirms a working tree first, handling worktrees,
#' dubious-ownership, and plain directories; suppressWarnings() keeps
#' git's non-zero exits from leaking as "had status" warnings.
#' @noRd
git_commit_count_since <- function(repo_dir, since_date) {
    inside <- tryCatch(
                       suppressWarnings(system2("git",
                c("-C", repo_dir, "rev-parse", "--is-inside-work-tree"),
                stdout = TRUE, stderr = FALSE)),
                       error = function(e) character(0L)
    )
    if (length(inside) == 0L || !identical(inside[1L], "true")) {
        return(0L)
    }

    # shQuote: the --since value contains a space, and system2() does not
    # quote arguments itself
    out <- tryCatch(
                    suppressWarnings(system2("git",
                c("-C", repo_dir, "rev-list", "--count",
                    shQuote(sprintf("--since=%s 00:00",
                                    as.character(since_date))),
                    "HEAD"),
                stdout = TRUE, stderr = FALSE)),
                    error = function(e) character(0L)
    )
    if (length(out) == 0L) {
        return(0L)
    }
    cnt <- suppressWarnings(as.integer(out[1L]))
    if (is.na(cnt)) {
        return(0L)
    }
    cnt
}

#' Recent one-line commits since a date, capped at n
#' @noRd
git_log_since <- function(repo_dir, since_date, n) {
    tryCatch(
             suppressWarnings(system2("git",
                                      c("-C", repo_dir, "log", "--oneline",
                                        shQuote(sprintf("--since=%s 00:00",
                            as.character(since_date))),
                                        sprintf("-%d", as.integer(n))),
                                      stdout = TRUE, stderr = FALSE)),
             error = function(e) character(0L)
    )
}
