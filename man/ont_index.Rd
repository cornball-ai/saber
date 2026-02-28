% tinyrox says don't edit this manually, but it can't stop you!
\name{ont_index}
\alias{ont_index}
\title{Build or update the ontology index}
\usage{
ont_index(vault_path)
}
\arguments{
\item{vault_path}{Path to the markdown vault directory.}
}
\value{
The database path (invisibly).
}
\description{
Parse markdown files from a vault and populate the SQLite index.
Build or update the ontology index from a markdown vault

Parses all markdown files in the vault, extracts frontmatter and typed
links, and writes them to the SQLite index. Performs incremental updates
based on file hashes.
}
