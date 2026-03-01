% tinyrox says don't edit this manually, but it can't stop you!
\name{briefing}
\alias{briefing}
\title{Project briefing}
\usage{
briefing(project = NULL,
         vault_path = file.path(path.expand("~"), ".cache", "basalt", "vault"),
         briefs_dir = file.path(path.expand("~"), ".cache", "basalt", "briefs"),
         memory_base = file.path(path.expand("~"), ".claude", "projects"),
         scan_dir = path.expand("~"), max_memory_lines = 30L)
}
\arguments{
\item{project}{Project name. If NULL, inferred from the current working
directory basename.}

\item{vault_path}{Path to the basalt vault.}

\item{briefs_dir}{Directory to write briefing markdown files.}

\item{memory_base}{Base directory for Claude Code project memory files.}

\item{scan_dir}{Directory to look for the project's git repo.}

\item{max_memory_lines}{Maximum lines to include from the memory file.}
}
\value{
The briefing text (character string), returned invisibly. Also
  written to \code{briefs_dir/{project}.md}.
}
\description{
Generate a concise project context briefing combining ontology,
  memory, todos, and recent git activity.
Generate a project briefing

Produces a concise markdown briefing for a project by combining ontology
relations, Claude Code memory files, current todo items, and recent git
commits. The briefing is written to \code{~/.cache/basalt/briefs/} so both
Claude and Troy can see the same context.
}
