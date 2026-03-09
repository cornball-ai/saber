% tinyrox says don't edit this manually, but it can't stop you!
\name{blast_radius}
\alias{blast_radius}
\title{Blast radius analysis}
\usage{
blast_radius(fn, project = NULL, scan_dir = path.expand("~"),
             cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols"))
}
\arguments{
\item{fn}{Character. Function name to search for.}

\item{project}{Character. Project name (or path to project directory).}

\item{scan_dir}{Directory to scan for downstream projects.}

\item{cache_dir}{Directory for symbol cache files.}
}
\value{
A data.frame with columns: caller, project, file, line.
}
\description{
Find all callers of a function across projects.
Find callers of a function across projects

Given a function name and project, finds all internal callers within that
project and all callers in downstream projects (projects whose DESCRIPTION
lists this one in Depends, Imports, or LinkingTo).
}
