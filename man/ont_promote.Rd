% tinyrox says don't edit this manually, but it can't stop you!
\name{ont_promote}
\alias{ont_promote}
\title{Promote a term with a stable ID}
\usage{
ont_promote(term, vault_path, prefix = "ONTO")
}
\arguments{
\item{term}{Term name to promote.}

\item{vault_path}{Path to the markdown vault directory.}

\item{prefix}{ID prefix (default "ONTO").}
}
\value{
The new ID (invisibly).
}
\description{
Write a stable ontology ID into a file's frontmatter.
Promote a term with a stable ID

Assigns a stable \code{PREFIX:NNNNNNN} identifier to a term by writing
it into the markdown file's YAML frontmatter.
}
