% tinyrox says don't edit this manually, but it can't stop you!
\name{ont_suggest}
\alias{ont_suggest}
\title{Suggest typed relations}
\usage{
ont_suggest(vault_path)
}
\arguments{
\item{vault_path}{Path to the markdown vault directory.}
}
\value{
A data.frame of suggestions with columns: subject, relation_type,
  object, reason.
}
\description{
Propose typed edges from untyped wikilinks.
Suggest typed relations from untyped links

Examines untyped wikilinks and proposes typed relations based on
heuristics: folder co-location, heading context, and link frequency.
Suggestions are written to the database with \code{confirmed = FALSE}.
}
