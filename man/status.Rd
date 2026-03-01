% tinyrox says don't edit this manually, but it can't stop you!
\name{status}
\alias{status}
\title{Ontology status summary}
\usage{
status(vault_path = NULL)
}
\arguments{
\item{vault_path}{Path to the vault.}
}
\value{
A list with class \code{basalt_status}.
}
\description{
Summary stats for the ontology index.
Get ontology status summary

Returns summary statistics about the ontology: term count, relation count,
promoted terms, and unconfirmed suggestions.
}
