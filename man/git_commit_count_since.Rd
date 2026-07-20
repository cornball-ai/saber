% tinyrox says don't edit this manually, but it can't stop you!
\name{git_commit_count_since}
\alias{git_commit_count_since}
\title{Count commits in a repository since a date}
\usage{
git_commit_count_since(repo_dir, since_date)
}
\arguments{
\item{repo_dir}{Path to a repository.}

\item{since_date}{A \code{Date} (or string in \code{YYYY-MM-DD} form).
Commits from 00:00 local time on this date count.}
}
\value{
Integer commit count.
}
\description{
Returns the number of commits on \code{HEAD} dated on or after
\code{since_date}, and \code{0L} for anything that is not a git
working tree (plain directories, missing paths). Worktrees and
dubious-ownership repositories are handled: a \code{git rev-parse}
check runs first, and git's non-zero exits never leak as warnings.
The counting primitive behind \code{\link{heartbeat}}, exported for
downstream tooling that composes its own activity reports.
}
\examples{
# A plain directory is not a repository: counts as zero
git_commit_count_since(tempdir(), Sys.Date() - 7)
}
