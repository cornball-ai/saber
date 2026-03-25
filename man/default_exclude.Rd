% tinyrox says don't edit this manually, but it can't stop you!
\name{default_exclude}
\alias{default_exclude}
\title{Default directories to exclude when scanning for projects}
\usage{
default_exclude()
}
\value{
Character vector of directory basenames.
}
\description{
Returns a character vector of directory basenames that are skipped
when scanning for downstream projects. Override by passing a custom
\code{exclude} vector to \code{\link{blast_radius}}.
}
\examples{
default_exclude()
}
