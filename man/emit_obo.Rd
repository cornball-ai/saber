% tinyrox says don't edit this manually, but it can't stop you!
\name{emit_obo}
\alias{emit_obo}
\title{Emit OBO format}
\usage{
emit_obo(vault_path = file.path(tools::R_user_dir("basalt", "cache"), "index"),
         outfile = NULL)
}
\arguments{
\item{vault_path}{Path to the vault.}

\item{outfile}{Path to write the OBO file. If NULL, writes to stdout.}
}
\value{
The output path (invisibly), or NULL if written to stdout.
}
\description{
Snapshot the ontology to OBO format.
Emit the ontology in OBO format

Writes the current ontology to a file in OBO 1.4 format.
}
