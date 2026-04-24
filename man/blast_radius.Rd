% tinyrox says don't edit this manually, but it can't stop you!
\name{blast_radius}
\alias{blast_radius}
\title{Blast radius analysis}
\usage{
blast_radius(fn, project = NULL, include = "r", scan_dir = path.expand("~"),
             cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols"),
             exclude = default_exclude())
}
\arguments{
\item{fn}{Character. Function name to search for.}

\item{project}{Character. Project name (or path to project directory).}

\item{include}{Character vector. Any of \code{"r"} (R source, default),
\code{"examples"} (roxygen \verb{@examples} blocks in the target
project), and \code{"vignettes"} (code chunks in the target project's
vignettes).}

\item{scan_dir}{Directory to scan for downstream projects.}

\item{cache_dir}{Directory for symbol cache files.}

\item{exclude}{Character vector of directory basenames to skip when
scanning for downstream projects.}
}
\value{
A data.frame with columns: caller, project, file, line, source.
  \code{source} is one of \code{"r"}, \code{"example"}, \code{"vignette"}.
}
\description{
Find all callers of a function across projects.
Find callers of a function across projects

Given a function name and project, finds all internal callers within that
project and all callers in downstream projects (projects whose DESCRIPTION
lists this one in Depends, Imports, or LinkingTo).

With \code{include = c("r", "examples", "vignettes")} the search can be
extended to references in the target project's roxygen \verb{@examples}
blocks and vignette code chunks (Rmd, qmd, Rnw). Documentation scanning is
target-project only; it does not walk downstream projects' docs.
}
\examples{
# Create a minimal project
d <- file.path(tempdir(), "blastpkg")
dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines("helper <- function(x) x + 1", file.path(d, "R", "helper.R"))
writeLines("main <- function(x) helper(x * 2)", file.path(d, "R", "main.R"))

# Find all callers of helper()
blast_radius("helper", project = d, scan_dir = tempdir(),
             cache_dir = tempdir())

# Include roxygen @examples and vignettes from the target project
blast_radius("helper", project = d, include = c("r", "examples", "vignettes"),
             scan_dir = tempdir(), cache_dir = tempdir())
}
