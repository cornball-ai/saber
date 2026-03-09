% tinyrox says don't edit this manually, but it can't stop you!
\name{symbols}
\alias{symbols}
\title{AST symbol index}
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
Parse R source files to extract function definitions and calls.
Build a symbol index for a project

Parses all \code{R/*.R} files in a project directory using
\code{getParseData()} to extract function definitions and function calls.
Results are cached as RDS in \code{~/.cache/R/saber/symbols/}.
}
