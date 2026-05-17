% tinyrox says don't edit this manually, but it can't stop you!
\name{fn_graph}
\alias{fn_graph}
\title{Code intelligence: function call graph}
\usage{
fn_graph(project_dir, include_external = FALSE, ...,
         cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols"))
}
\arguments{
\item{project_dir}{Path to the project directory (an R package root).}

\item{include_external}{If \code{TRUE}, also include nodes for
functions called from other packages. Default \code{FALSE}.}

\item{...}{Passed through to \code{\link{graph_svg}} (e.g.,
\code{width}, \code{height}, \code{iterations}, \code{seed}).}

\item{cache_dir}{Directory for the underlying \code{\link{symbols}}
cache. Pass \code{tempdir()} (or any non-default path) when running
examples / tests to avoid writing to the user's persistent cache.
Name-only argument — must be passed by name.}
}
\value{
Character vector of SVG lines. Write with \code{writeLines()}.
}
\description{
Render a project's internal function call graph as interactive
  SVG.
Render a function call graph for an R project

Pulls the AST symbol index via \code{\link{symbols}} and renders
internal function-to-function call edges as SVG. External calls
(into other packages) are dropped by default.
}
\examples{
d <- file.path(tempdir(), "fngdemo")
dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines(c("Package: demo", "Version: 0.1.0"),
           file.path(d, "DESCRIPTION"))
writeLines("add <- function(x, y) x + y", file.path(d, "R", "add.R"))
writeLines("double <- function(x) add(x, x)",
           file.path(d, "R", "double.R"))
svg <- fn_graph(d, cache_dir = tempdir())
writeLines(svg, tempfile(fileext = ".svg"))
}
