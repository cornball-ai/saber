% tinyrox says don't edit this manually, but it can't stop you!
\name{context_audit}
\alias{context_audit}
\title{Audit context inclusion and token costs}
\usage{
context_audit(manifest, layer_tokens = 2000L, total_tokens = 8000L)
}
\arguments{
\item{manifest}{A manifest returned by \code{\link{context_manifest}}.}

\item{layer_tokens}{Estimated-token warning threshold for one source.}

\item{total_tokens}{Estimated-token warning threshold for rendered context.}
}
\value{
A \code{saber_context_audit} list with metadata-only sources,
  findings (source_id, code, severity, related_id), total emitted sizes,
  and the estimator label. Native tokens are not part of the emitted total.
}
\description{
Reports metadata, exact duplicate sources, native overlap, missing or
unreadable files, audience exclusions, explicit truncation, and size
thresholds. Does not print or retain source bodies in its result, execute
snippets, or infer semantic contradictions from arbitrary text.
}
\examples{
m <- context_manifest("corteza", discover = FALSE,
    extra_sources = list(list(id = "note", kind = "memory", text = "A note.")))
context_audit(m, layer_tokens = 1)
}
