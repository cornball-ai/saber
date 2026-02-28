% tinyrox says don't edit this manually, but it can't stop you!
\name{ont_emit_obo}
\alias{ont_emit_obo}
\title{Emit OBO format}
\usage{
ont_emit_obo(db_path = NULL, outfile = NULL, vault_path = NULL)
}
\arguments{
\item{db_path}{Path to the SQLite database.}

\item{outfile}{Path to write the OBO file. If NULL, writes to stdout.}

\item{vault_path}{Path to the vault (used to derive db_path if db_path is NULL).}
}
\value{
The output path (invisibly), or NULL if written to stdout.
}
\description{
Snapshot the ontology to OBO format.
Emit the ontology in OBO format

Writes the current ontology to a file in OBO 1.4 format.
}
