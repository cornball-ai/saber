% tinyrox says don't edit this manually, but it can't stop you!
\name{pkg_graph}
\alias{pkg_graph}
\title{Project discovery — package dependency graph}
\usage{
pkg_graph(scan_dir = path.expand("~"), packages = NULL,
          include_suggests = FALSE, ...)
}
\arguments{
\item{scan_dir}{Directory to scan for project directories.}

\item{packages}{Optional character vector limiting the graph to
these packages.}

\item{include_suggests}{If \code{TRUE}, also include edges for
packages in each project's \code{Suggests} field. Default
\code{FALSE} (only \code{Depends} and \code{Imports}).}

\item{...}{Passed through to \code{\link{graph_svg}}.}
}
\value{
Character vector of SVG lines. Write with \code{writeLines()}.
}
\description{
Render the dependency graph across a set of R packages as
  interactive SVG.
Render a package-level dependency graph

Discovers R packages under \code{scan_dir} via \code{\link{projects}},
parses each one's \code{Depends} and \code{Imports} fields, and
renders edges between packages that both live in \code{scan_dir}.
External CRAN dependencies are dropped.
}
\examples{
d <- file.path(tempdir(), "pkgdemo")
dir.create(file.path(d, "parent"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(d, "child"), showWarnings = FALSE)
writeLines(c("Package: parent", "Title: P", "Version: 0.1.0"),
           file.path(d, "parent", "DESCRIPTION"))
writeLines(c("Package: child", "Title: C", "Version: 0.1.0",
             "Imports: parent"),
           file.path(d, "child", "DESCRIPTION"))
svg <- pkg_graph(scan_dir = d)
writeLines(svg, tempfile(fileext = ".svg"))
}
