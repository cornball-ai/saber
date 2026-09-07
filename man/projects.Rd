% tinyrox says don't edit this manually, but it can't stop you!
\name{projects}
\alias{projects}
\title{Discover R package projects}
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
Scans a directory for subdirectories containing a DESCRIPTION file and
returns their metadata. Symbolic-link aliases of the same directory are
reported once, preferring its non-alias path when present. Separate
checkouts remain separate even when they declare the same package name.
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
