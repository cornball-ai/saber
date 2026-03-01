% tinyrox says don't edit this manually, but it can't stop you!
\name{add}
\alias{add}
\title{Add terms and relations programmatically}
\usage{
add(terms = NULL, relations = NULL, db_path = NULL, vault_path = NULL,
    annotations_dir = file.path(path.expand("~"), ".cache", "basalt", "annotations"))
}
\arguments{
\item{terms}{Character vector of term names to add.}

\item{relations}{A data.frame with columns: subject, relation_type, object.}

\item{db_path}{Path to the SQLite database.}

\item{vault_path}{Path to the vault (used to derive db_path if db_path is NULL).}

\item{annotations_dir}{Directory for persistent annotation files. Set to
NULL to skip writing annotations. Default: \code{~/.cache/basalt/annotations}.}
}
\value{
A list with counts of terms and relations added (invisibly).
}
\description{
Bulk-insert terms and relations into the ontology, with
  optional persistent annotation files.
Add terms and relations to the ontology

Insert terms and/or relations directly into the SQLite index. Optionally
writes a markdown annotation file to persist additions across re-indexes.
}
