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

#' Count commits in a repository since a date
#'
#' Returns the number of commits on \code{HEAD} dated on or after
#' \code{since_date}, and \code{0L} for anything that is not a git
#' working tree (plain directories, missing paths). Worktrees and
#' dubious-ownership repositories are handled: a \code{git rev-parse}
#' check runs first, and git's non-zero exits never leak as warnings.
#' The counting primitive behind \code{\link{heartbeat}}, exported for
#' downstream tooling that composes its own activity reports.
#'
#' @param repo_dir Path to a repository.
#' @param since_date A \code{Date} (or string in \code{YYYY-MM-DD} form).
#'   Commits from 00:00 local time on this date count.
#' @return Integer commit count.
#' @examples
#' # A plain directory is not a repository: counts as zero
#' git_commit_count_since(tempdir(), Sys.Date() - 7)
#' @export
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

#' List recent commits in a repository
#'
#' Returns up to \code{n} commit lines from \code{HEAD}, newest first.
#' With \code{format = "oneline"} each line is git's \code{--oneline}
#' (short hash and subject); with \code{format = "iso"} each line is
#' tab-separated ISO-local timestamp, short hash, and subject. A
#' \code{NULL} \code{since_date} means no lower bound. Anything that is
#' not a git working tree returns \code{character(0)}. The log
#' primitive behind \code{\link{heartbeat}}, exported for downstream
#' tooling that composes its own activity reports.
#'
#' @param repo_dir Path to a repository.
#' @param since_date A \code{Date} (or string in \code{YYYY-MM-DD}
#'   form), or \code{NULL} for no lower bound. Commits from 00:00 local
#'   time on this date are included.
#' @param n Integer. Maximum commits to return.
#' @param format \code{"oneline"} (default) or \code{"iso"}.
#' @return Character vector of commit lines (possibly empty).
#' @examples
#' # A plain directory is not a repository: empty log
#' git_log_since(tempdir(), Sys.Date() - 7)
#' @export
git_log_since <- function(repo_dir, since_date = NULL, n = 5L,
                          format = c("oneline", "iso")) {
    format <- match.arg(format)
    fmt_args <- if (identical(format, "iso")) {
        c("--date=iso-local", "--pretty=format:%ad%x09%h%x09%s")
    } else {
        "--oneline"
    }
    # shQuote: the --since value contains a space, and system2() does not
    # quote arguments itself
    since_args <- if (is.null(since_date)) {
        character(0L)
    } else {
        shQuote(sprintf("--since=%s 00:00", as.character(since_date)))
    }
    out <- tryCatch(
                    suppressWarnings(system2("git",
                                             c("-C", repo_dir, "log", fmt_args, since_args,
                                               sprintf("-%d", as.integer(n))),
                                             stdout = TRUE, stderr = FALSE)),
                    error = function(e) character(0L)
    )
    # A failed git (non-repo, empty repo) exits non-zero and system2()
    # tags the result with a status attribute; that is an empty log
    if (!is.null(attr(out, "status"))) {
        return(character(0L))
    }
    out
}
