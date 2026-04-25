% tinyrox says don't edit this manually, but it can't stop you!
\name{projects}
\alias{projects}
\title{Project discovery}
\usage{
projects(scan_dir = path.expand("~"), exclude = default_exclude())
}
\arguments{
\item{scan_dir}{Directory to scan for project directories.}

\item{exclude}{Character vector of directory basenames to skip.}
}
\value{
A data.frame with columns: package, title, version, path, depends,
  imports.
}
\description{
Discover R package projects and map their dependency
  relationships.
Discover R package projects

Scans a directory for subdirectories containing a DESCRIPTION file and
returns their metadata.
}
\examples{
d <- file.path(tempdir(), "scandir")
dir.create(d, showWarnings = FALSE)
pkg <- file.path(d, "mypkg")
dir.create(pkg, showWarnings = FALSE)
writeLines(c("Package: mypkg", "Title: Demo", "Version: 0.1.0"),
           file.path(pkg, "DESCRIPTION"))
projects(scan_dir = d)
}
