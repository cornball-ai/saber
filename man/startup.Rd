% tinyrox says don't edit this manually, but it can't stop you!
\name{startup}
\alias{startup}
\title{Startup: discover project metadata and build unified ontology}
\usage{
startup(scan_dir = path.expand("~"),
        cache_dir = tools::R_user_dir("basalt", "cache"),
        claude_dir = file.path(path.expand("~"), ".cache", "claude"),
        memory_dir = file.path(path.expand("~"), ".claude", "projects"))
}
\arguments{
\item{scan_dir}{Directory to scan for projects (default: home directory).}

\item{cache_dir}{Directory for the ontology index and annotations
(default: \code{tools::R_user_dir("basalt", "cache")}).}

\item{claude_dir}{Directory where Claude Code reads its global CLAUDE.md.
Used only to check if the instructions file needs updating. Set to NULL
to suppress the copy hint. Nothing is written to this directory.}

\item{memory_dir}{Directory containing Claude Code project memory files
(default: \code{~/.claude/projects}). Set to NULL to skip.}
}
\value{
A \code{basalt_status} object (invisibly).
}
\description{
Scan home directory for project metadata, auto-register
  projects as terms, infer relations from DESCRIPTION files, and install
  Claude Code instructions.
Build a unified ontology from project metadata files

Scans for CLAUDE.md, AGENT.md, fyi.md, README.md, and DESCRIPTION files
across project directories. Also discovers Claude Code memory files from
\code{~/.claude/projects/*/memory/*.md}. Every project with recognized
metadata becomes a term automatically. R package dependencies from
DESCRIPTION files generate \code{uses} relations. Central annotation
files from \code{annotations_dir} are parsed for typed links.

Files are read in place — nothing is copied. The index (three TSV files)
is written to \code{cache_dir}.
}
