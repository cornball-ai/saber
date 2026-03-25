% tinyrox says don't edit this manually, but it can't stop you!
\name{pkg_exports}
\alias{pkg_exports}
\title{Package introspection}
\usage{
pkg_exports(package, pattern = NULL)
}
\arguments{
\item{package}{Character. Package name.}

\item{pattern}{Optional regex to filter function names.}
}
\value{
A data.frame with columns: name, args.
}
\description{
Query installed R packages for exports, internals, and help.
List exported functions of a package

Returns a data.frame of exported functions with their argument signatures.
}
\examples{
pkg_exports("tools")
pkg_exports("tools", pattern = "^Rd")
}
