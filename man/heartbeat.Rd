% tinyrox says don't edit this manually, but it can't stop you!
\name{heartbeat}
\alias{heartbeat}
\title{Summarize recent git activity across projects}
\usage{
heartbeat(days = 7L, scan_dir = path.expand("~"), n = 5L,
          exclude = default_exclude(),
          briefs_dir = file.path(tools::R_user_dir("saber", "cache"), "briefs"))
}
\arguments{
\item{days}{Integer. Lookback window in days.}

\item{scan_dir}{Directory whose immediate subdirectories are scanned.}

\item{n}{Integer. Maximum commits to list per active project.}

\item{exclude}{Character vector of directory basenames to skip.}

\item{briefs_dir}{Directory to write the heartbeat markdown file.}
}
\value{
The heartbeat text (character string), returned invisibly.
  Emitted via \code{message()} and written to
  \code{briefs_dir/_heartbeat.md}.
}
\description{
Scans every git repository directly under \code{scan_dir}, counts
commits inside the lookback window, and produces a markdown summary of
the active projects with their most recent commits, busiest first. The
complement to \code{\link{briefing}}: \code{briefing()} is one project
in depth, \code{heartbeat()} is every project at a glance.
}
\examples{
root <- file.path(tempdir(), "hbscan")
dir.create(root, showWarnings = FALSE)
heartbeat(days = 7, scan_dir = root,
          briefs_dir = file.path(tempdir(), "briefs"))
}
