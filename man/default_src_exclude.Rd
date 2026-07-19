% tinyrox says don't edit this manually, but it can't stop you!
\name{default_src_exclude}
\alias{default_src_exclude}
\title{Default directories to exclude when scanning for source files}
\usage{
default_src_exclude()
}
\value{
Character vector of directory basenames.
}
\description{
Returns a character vector of directory basenames that
\code{\link{src_symbols}} skips while scanning: everything in
\code{\link{default_exclude}} (user directories such as
\code{Documents}, plus caches and build artifacts), extended with
dependency and build trees whose sources are not the project's own
(including cargo's \code{target}).
Hidden directories (e.g. \code{.git}) and \code{*.Rcheck} directories
are always skipped, whatever the \code{exclude} value. Extend it for
vendored code, e.g. \code{c(default_src_exclude(), "tree-sitter")}.
}
\examples{
default_src_exclude()
}
