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
\code{\link{src_symbols}} skips while scanning: dependency and build
trees whose sources are not the project's own. Hidden directories
(e.g. \code{.git}) are always skipped. Extend it for vendored code,
e.g. \code{c(default_src_exclude(), "tree-sitter")}.
}
\examples{
default_src_exclude()
}
