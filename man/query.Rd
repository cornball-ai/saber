% tinyrox says don't edit this manually, but it can't stop you!
\name{query}
\alias{query}
\title{Query the ontology graph}
\usage{
query(term, relation, direction = c("ancestors", "descendants", "siblings"),
      db_path = NULL, vault_path = NULL)
}
\arguments{
\item{term}{Term name or ID to start from.}

\item{relation}{Relation type to traverse (e.g., "is_a", "part_of").}

\item{direction}{One of "ancestors", "descendants", or "siblings".}

\item{db_path}{Path to the SQLite database. If NULL, not usable.}

\item{vault_path}{Path to the vault (used to derive db_path if db_path is NULL).}
}
\value{
A data.frame with columns: id, name, distance.
}
\description{
Traverse typed relations in the ontology index.
Query the ontology graph

Traverse typed relations starting from a term. Supports ancestor,
descendant, and sibling traversal.
}
