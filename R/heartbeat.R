#' @title Weekly heartbeat
#' @description Cross-project activity summary combining git history, current
#'   todos, and recent ontology changes.

#' Generate a weekly heartbeat summary
#'
#' Scans git logs across all project directories, reads the current todo file,
#' and checks for recent ontology annotations. The heartbeat is written to
#' \code{~/.cache/basalt/briefs/_heartbeat.md}.
#'
#' @param scan_dir Directory to scan for project git repos.
#' @param briefs_dir Directory to write the heartbeat markdown file.
#' @param annotations_dir Directory containing basalt annotation files.
#' @param days Number of days to look back for git history.
#' @return The heartbeat text (character string), returned invisibly.
#' @export
heartbeat <- function(scan_dir = path.expand("~"),
                          briefs_dir = file.path(path.expand("~"),
                                                 ".cache", "basalt", "briefs"),
                          annotations_dir = file.path(path.expand("~"),
                                                      ".cache", "basalt",
                                                      "annotations"),
                          days = 7L) {
  dir.create(briefs_dir, recursive = TRUE, showWarnings = FALSE)

  lines <- c(
    "# Heartbeat",
    sprintf("_Generated %s (last %d days)_",
            format(Sys.time(), "%Y-%m-%d %H:%M"), days),
    ""
  )

  # --- Git activity across projects ---
  git_lines <- heartbeat_git(scan_dir, days)
  if (length(git_lines) > 0L) lines <- c(lines, git_lines, "")

  # --- Recent annotations ---
  ann_lines <- heartbeat_annotations(annotations_dir, days)
  if (length(ann_lines) > 0L) lines <- c(lines, ann_lines, "")

  text <- paste(lines, collapse = "\n")

  outfile <- file.path(briefs_dir, "_heartbeat.md")
  writeLines(lines, outfile)

  invisible(text)
}

#' Git activity across projects
#' @noRd
heartbeat_git <- function(scan_dir, days) {
  project_dirs <- list.dirs(scan_dir, recursive = FALSE, full.names = TRUE)
  since_arg <- sprintf("--since='%d days ago'", days)

  activity <- list()
  for (d in project_dirs) {
    if (!dir.exists(file.path(d, ".git"))) next
    log <- tryCatch(
      system2("git", c("-C", d, "log", "--oneline", since_arg),
              stdout = TRUE, stderr = FALSE),
      error = function(e) character(0L)
    )
    if (length(log) > 0L) {
      activity[[basename(d)]] <- log
    }
  }

  if (length(activity) == 0L) return(character(0L))

  # Sort by most commits
  counts <- vapply(activity, length, integer(1L))
  activity <- activity[order(counts, decreasing = TRUE)]

  lines <- "## This week's commits"
  for (proj in names(activity)) {
    commits <- activity[[proj]]
    n <- length(commits)
    # Show count and most recent 3
    lines <- c(lines, sprintf("### %s (%d commit%s)", proj, n,
                              if (n == 1L) "" else "s"))
    show <- if (n > 3L) commits[1:3] else commits
    for (c in show) {
      lines <- c(lines, sprintf("- %s", c))
    }
    if (n > 3L) {
      lines <- c(lines, sprintf("- _... +%d more_", n - 3L))
    }
  }
  lines
}

#' Recent annotation files
#' @noRd
heartbeat_annotations <- function(annotations_dir, days) {
  if (is.null(annotations_dir) || !dir.exists(annotations_dir)) {
    return(character(0L))
  }

  files <- list.files(annotations_dir, pattern = "\\.md$", full.names = TRUE)
  if (length(files) == 0L) return(character(0L))

  # Filter to files modified in the last N days
  cutoff <- Sys.time() - as.difftime(days, units = "days")
  mtimes <- file.mtime(files)
  recent <- files[mtimes >= cutoff]

  if (length(recent) == 0L) return(character(0L))

  lines <- "## Recent ontology changes"
  for (f in recent) {
    lines <- c(lines, sprintf("- %s (%s)", basename(f),
                              format(file.mtime(f), "%Y-%m-%d")))
  }
  lines
}
