% tinyrox says don't edit this manually, but it can't stop you!
\name{git_log_since}
\alias{git_log_since}
\title{List recent commits in a repository}
\usage{
git_log_since(repo_dir, since_date = NULL, n = 5L, format = c("oneline", "iso"))
}
\arguments{
\item{repo_dir}{Path to a repository.}

\item{since_date}{A \code{Date} (or string in \code{YYYY-MM-DD}
form), or \code{NULL} for no lower bound. Commits from 00:00 local
time on this date are included.}

\item{n}{Integer. Maximum commits to return.}

\item{format}{\code{"oneline"} (default) or \code{"iso"}.}
}
\value{
Character vector of commit lines (possibly empty).
}
\description{
Returns up to \code{n} commit lines from \code{HEAD}, newest first.
With \code{format = "oneline"} each line is git's \code{--oneline}
(short hash and subject); with \code{format = "iso"} each line is
tab-separated ISO-local timestamp, short hash, and subject. A
\code{NULL} \code{since_date} means no lower bound. Anything that is
not a git working tree returns \code{character(0)}. The log
primitive behind \code{\link{heartbeat}}, exported for downstream
tooling that composes its own activity reports.
}
\examples{
# A plain directory is not a repository: empty log
git_log_since(tempdir(), Sys.Date() - 7)
}
