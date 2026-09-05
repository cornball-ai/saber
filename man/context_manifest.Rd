% tinyrox says don't edit this manually, but it can't stop you!
\name{context_manifest}
\alias{context_manifest}
\title{Build a source manifest for agent context}
\usage{
context_manifest(
  agent,
  project_dir = getwd(),
  workspace_dir = NULL,
  shared_path = NULL,
  native_paths = character(),
  extra_sources = list(),
  budgets = list(),
  discover = TRUE
)
}
\arguments{
\item{agent}{Nonempty consumer name, such as \code{"corteza"}.}

\item{project_dir}{Project directory. Relative source paths resolve here.}

\item{workspace_dir}{Optional directory containing USER.md and SOUL.md.}

\item{shared_path}{Shared instruction file. NULL uses AGENTS_GLOBAL_MD,
then ~/.config/agents/GLOBAL.md. FALSE disables shared-file discovery.}

\item{native_paths}{Character vector of files the caller confirms are
already loaded by the consumer. These are measured but never reinjected.}

\item{extra_sources}{List of source descriptors, described below.}

\item{budgets}{Named list of budgets keyed by source id or kind. Each
contains max_chars and/or max_lines, nonnegative integers or Inf.
A source-id budget takes precedence over a kind budget. Kind budgets
are shared by matching sources in rendering order.}

\item{discover}{Include standard shared, project, and workspace sources?
FALSE uses only native_paths and extra_sources.}
}
\value{
A \code{saber_context_manifest} list with schema_version, agent,
  project_dir, estimator, budgets, a sources data frame, and named
  fragments. The data frame records paths, audience, delivery, inclusion
  reasons, duplicate ids, source and emitted sizes/hashes, and budget loss.
  \code{requested_path} preserves the original source path, \code{path}
  resolves it against project_dir and expands tilde, and \code{canonical_path}
  resolves existing paths and symbolic links. Generated text uses empty paths.
}
\description{
Discovers shared and project instructions, records source provenance, and
selects context without changing the legacy \code{\link{agent_context}} API.
Printing the result shows metadata only. Source text is available through
\code{\link{context_render}} and the manifest's \code{fragments} field.
}
\details{
Discovery prefers AGENTS.md and falls back to CLAUDE.md when AGENTS.md is
missing, empty, or unreadable. Both candidates remain in the manifest.
Shared preferences and workspace USER.md are independent sources.
The Claude global file, memories, ancestor instructions, skills, and
briefings are not discovered implicitly. Supply those as explicit sources.
Native loading is declared by the caller, never inferred from agent alone.

Each extra source is a list with a unique \code{id}, a \code{kind}, and
exactly one of \code{path} or scalar UTF-8 \code{text}. Optional fields are
\code{audience} (character vector, default \code{"*"}), \code{delivery}
(\code{"consumer"}, \code{"hook"}, or \code{"native"}), \code{origin},
\code{scope}, \code{config_path}, \code{native_evidence}, and numeric
\code{order}. Defaults preserve discovery then extra-source order; set
order to place generated layers before or between discovered sources.

Files are read as UTF-8 without rewriting whitespace or line endings.
Deduplication compares canonical paths and exact bytes before budgets,
with native sources for the current audience taking precedence regardless
of order. Missing and unreadable native files can still suppress the same path,
but cannot establish equality to other files. MD5 fingerprints identify
content, not authenticity; byte equality confirms content matches.

Budgets apply to emitted fragments, excluding the blank-line separators
inserted by context_render(). Native sources do not consume these budgets.
Truncation is recorded, with no unbudgeted marker inserted into the text.
By default nothing is truncated. Lines count physical lines, excluding an
empty line after a final newline; tokens are ceiling(characters / 4).
No source code is evaluated and no persistent cache is written.
}
\examples{
m <- context_manifest("corteza", discover = FALSE,
    extra_sources = list(list(id = "runtime", kind = "runtime",
                             text = "R objects persist across turns.")))
context_audit(m)
cat(context_render(m))
}
