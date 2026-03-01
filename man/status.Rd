% tinyrox says don't edit this manually, but it can't stop you!
\name{status}
\alias{status}
\title{Ontology status summary}
\usage{
status(db_path = NULL, vault_path = NULL)
}
\arguments{
\item{db_path}{Path to the SQLite database.}

\item{vault_path}{Path to the vault (used to derive db_path if db_path is NULL).}
}
\value{
A list with components: terms, promoted, relations, suggestions,
  relation_types.
}
\description{
Summary stats for the ontology index.
Get ontology status summary

Returns summary statistics about the ontology: term count, relation count,
promoted terms, and unconfirmed suggestions.
}
