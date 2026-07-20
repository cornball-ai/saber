% tinyrox says don't edit this manually, but it can't stop you!
\name{symbols}
\alias{symbols}
\title{Build a symbol index for a project}
\usage{
symbols(project_dir,
        cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols"))
}
\arguments{
\item{project_dir}{Path to the project directory.}

\item{cache_dir}{Directory for symbol cache files.}
}
\value{
A list with components:
  \describe{
    \item{defs}{data.frame(name, file, line, exported)}
    \item{calls}{data.frame(caller, callee, file, line)}
  }
}
\description{
Parses all \code{R/*.R} files in a project directory using
\code{getParseData()} to extract function definitions and function calls.
Results are cached as RDS in the user cache directory.
}
\examples{
# Create a minimal project with R source files
d <- file.path(tempdir(), "demopkg")
dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines("add <- function(x, y) x + y", file.path(d, "R", "add.R"))
writeLines("double <- function(x) add(x, x)", file.path(d, "R", "double.R"))

idx <- symbols(d, cache_dir = tempdir())
idx$defs   # function definitions
idx$calls  # call relationships (double calls add)
}
