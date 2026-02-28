% tinyrox says don't edit this manually, but it can't stop you!
\name{ont_startup}
\alias{ont_startup}
\title{Startup: discover project metadata and build unified ontology}
\usage{
ont_startup(
  scan_dir = path.expand("~"),
  db_dir = file.path(path.expand("~"), ".cache", "basalt"),
  claude_dir = file.path(path.expand("~"), ".cache", "claude")
)
}
\arguments{
\item{scan_dir}{Directory to scan for projects (default: home directory).}

\item{db_dir}{Directory for the unified ontology database and staging vault
(default: \code{~/.cache/basalt}).}

\item{claude_dir}{Directory for Claude Code instructions file
(default: \code{~/.cache/claude}).}
}
\value{
An \code{ont_status} object (invisibly).
}
\description{
Scan home directory for project metadata, auto-register
  projects as terms, infer relations from DESCRIPTION files, and install
  Claude Code instructions.
Build a unified ontology from project metadata files

Scans for CLAUDE.md, AGENT.md, fyi.md, and DESCRIPTION files across
project directories. Every project with recognized metadata becomes a
term automatically. R package dependencies from DESCRIPTION files
generate \code{uses} relations. Central annotation files from
\code{~/.cache/basalt/annotations/} are included in the index.
}
