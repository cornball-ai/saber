% tinyrox says don't edit this manually, but it can't stop you!
\name{pkg_internals}
\alias{pkg_internals}
\title{List internal (non-exported) functions of a package}
\usage{
pkg_internals(package, pattern = NULL)
}
\arguments{
\item{package}{Character. Package name.}

\item{pattern}{Optional regex to filter function names.}
}
\value{
A data.frame with columns: name, args.
}
\description{
Returns functions defined in a package namespace but not exported.
}
\examples{
pkg_internals("tools", pattern = "^check")
}
