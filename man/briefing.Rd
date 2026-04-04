% tinyrox says don't edit this manually, but it can't stop you!
\name{briefing}
\alias{briefing}
\title{Project briefings}
\usage{
briefing(project = NULL, scan_dir = path.expand("~"), agent = NULL,
         memory_base = file.path(path.expand("~"), ".claude", "projects"),
         briefs_dir = file.path(tools::R_user_dir("saber", "cache"), "briefs"),
         max_memory_lines = 30L)
}
\arguments{
\item{project}{Project name. If NULL, inferred from the current working
directory basename.}

\item{scan_dir}{Directory to scan for project directories.}

\item{agent}{Which coding agent is calling: \code{"claude"}, \code{"codex"},
or \code{NULL} (interactive / unknown). When \code{"claude"}, the briefing
skips 'Claude Code' memory (which 'Claude Code' autoloads separately).
Other values include it.}

\item{memory_base}{Base directory for 'Claude Code' project memory files.}

\item{briefs_dir}{Directory to write briefing markdown files.}

\item{max_memory_lines}{Maximum lines to include from the memory file.}
}
\value{
The briefing text (character string), returned invisibly. Printed
  to stdout and written to \code{briefs_dir/{project}.md}.
}
\description{
Generate project context for AI coding agents.
Generate a project briefing

Produces a concise markdown briefing combining DESCRIPTION metadata,
downstream dependents, 'Claude Code' memory (when not running inside
'Claude Code' itself), and recent git commits.
Written to the user cache directory so both the agent and user
see the same context.
}
\examples{
d <- file.path(tempdir(), "briefpkg")
dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines(c("Package: briefpkg", "Title: Demo", "Version: 0.1.0"),
           file.path(d, "DESCRIPTION"))
briefing("briefpkg", scan_dir = tempdir(),
         briefs_dir = file.path(tempdir(), "briefs"))
}
