% tinyrox says don't edit this manually, but it can't stop you!
\name{heartbeat}
\alias{heartbeat}
\title{Weekly heartbeat}
\usage{
heartbeat(scan_dir = path.expand("~"),
          briefs_dir = file.path(tools::R_user_dir("basalt", "cache"), "briefs"),
          annotations_dir = file.path(tools::R_user_dir("basalt", "cache"), "annotations"),
          days = 7L)
}
\arguments{
\item{scan_dir}{Directory to scan for project git repos.}

\item{briefs_dir}{Directory to write the heartbeat markdown file.}

\item{annotations_dir}{Directory containing basalt annotation files.}

\item{days}{Number of days to look back for git history.}
}
\value{
The heartbeat text (character string), returned invisibly.
}
\description{
Cross-project activity summary combining git history, current
  todos, and recent ontology changes.
Generate a weekly heartbeat summary

Scans git logs across all project directories, reads the current todo file,
and checks for recent ontology annotations. The heartbeat is written to
\code{~/.cache/basalt/briefs/_heartbeat.md}.
}
