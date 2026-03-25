% tinyrox says don't edit this manually, but it can't stop you!
\name{find_downstream}
\alias{find_downstream}
\title{Find projects that depend on a given package}
\usage{
find_downstream(package, scan_dir = path.expand("~"),
                exclude = default_exclude())
}
\arguments{
\item{package}{Character. Package name to search for.}

\item{scan_dir}{Directory to scan for project directories.}

\item{exclude}{Character vector of directory basenames to skip.}
}
\value{
Character vector of project names that depend on \code{package}.
}
\description{
Scans DESCRIPTION files in project directories under \code{scan_dir}
for Depends, Imports, or LinkingTo fields that reference \code{package}.
}
\examples{
d <- file.path(tempdir(), "dsdir")
dir.create(d, showWarnings = FALSE)
pkg <- file.path(d, "child")
dir.create(pkg, showWarnings = FALSE)
writeLines(c("Package: child", "Version: 0.1.0", "Imports: parent"),
           file.path(pkg, "DESCRIPTION"))
find_downstream("parent", scan_dir = d)
}
