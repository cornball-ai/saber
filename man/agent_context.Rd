% tinyrox says don't edit this manually, but it can't stop you!
\name{agent_context}
\alias{agent_context}
\title{Agent context loading}
\usage{
agent_context(agent = NULL, project_dir = getwd(), workspace_dir = NULL,
              memory_base = file.path(path.expand("~"), ".claude", "projects"),
              claude_global_path = file.path(path.expand("~"), ".claude", "CLAUDE.md"),
              include_memory = NULL, include_project = NULL,
              include_global = NULL, include_soul = NULL,
              max_memory_lines = 100L)
}
\arguments{
\item{agent}{Consumer identifier: \code{"claude"}, \code{"codex"},
\code{"llamar"}, or \code{NULL} (interactive / unknown).}

\item{project_dir}{Project directory to scan for CLAUDE.md / AGENTS.md.}

\item{workspace_dir}{Optional directory containing SOUL.md and USER.md
(e.g. \code{~/.llamar/workspace}). If \code{NULL}, those files are
skipped.}

\item{memory_base}{Base directory for 'Claude Code' project memory files.}

\item{claude_global_path}{Path to the global 'Claude Code' instructions
file. Defaults to \code{~/.claude/CLAUDE.md}.}

\item{include_memory}{Override default for memory inclusion. Use
\code{TRUE}/\code{FALSE} to force, or \code{NULL} for the agent default.}

\item{include_project}{Override default for project instructions
(CLAUDE.md / AGENTS.md).}

\item{include_global}{Override default for global instructions
(~/.claude/CLAUDE.md / USER.md).}

\item{include_soul}{Override default for SOUL.md inclusion.}

\item{max_memory_lines}{Maximum lines to include from the memory file.}
}
\value{
Character string of assembled context, or empty string if no
  context applies.
}
\description{
Load standard context files for AI coding agents.
Load context files for an AI coding agent

Returns assembled context (memory, project/global instructions, agent
identity files) tailored to a specific consumer. Files autoloaded by the
agent natively are skipped to avoid duplication.

Defaults per agent:
\itemize{
  \item \code{"claude"} - skips project memory and CLAUDE.md files
    (autoloaded by 'Claude Code'). Loads AGENTS.md, USER.md, and SOUL.md
    when present.
  \item \code{"codex"} - skips AGENTS.md (autoloaded by Codex). Loads
    project memory, CLAUDE.md, USER.md, and SOUL.md when present.
  \item \code{"llamar"} or \code{NULL} - loads everything available.
}

Project and global instructions are resolved by trying both naming
conventions and picking the file relevant to the consumer:
\itemize{
  \item Project: \code{CLAUDE.md} or \code{AGENTS.md}
  \item Global: \code{~/.claude/CLAUDE.md} or
    \code{<workspace_dir>/USER.md}
}

Override the defaults with the \code{include_*} parameters.
}
\examples{
\dontrun{
# Codex agent in current project
saber::agent_context(agent = "codex")

# llamaR with workspace files
saber::agent_context(agent = "llamar",
                     workspace_dir = "~/.llamar/workspace")

# Force-include memory regardless of agent default
saber::agent_context(agent = "claude", include_memory = TRUE)
}
}
