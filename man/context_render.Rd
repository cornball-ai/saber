% tinyrox says don't edit this manually, but it can't stop you!
\name{context_render}
\alias{context_render}
\title{Render the selected context fragments}
\usage{
context_render(manifest)
}
\arguments{
\item{manifest}{A manifest returned by \code{\link{context_manifest}}.}
}
\value{
A character string, or \code{""} when no fragments are included.
}
\description{
Returns included injectable fragments in manifest order, joined with two
newlines. Native and skipped sources are excluded. This is an explicit
request for source contents; printing a manifest or audit does not show them.
}
\examples{
m <- context_manifest("corteza", discover = FALSE,
    extra_sources = list(list(id = "note", kind = "memory", text = "A note.")))
context_render(m)
}
