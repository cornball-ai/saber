% tinyrox says don't edit this manually, but it can't stop you!
\name{adjacency}
\alias{adjacency}
\title{Dependency graph matrix and clustering}
\usage{
adjacency(vault_path = file.path(tools::R_user_dir("basalt", "cache"), "index"),
          weights = c(depends = 1, imports = 1, links_to = 0.8, suggests = 0.3, is_a = 0.5, part_of = 0.5, uses = 1),
          symmetric = TRUE)
}
\arguments{
\item{vault_path}{Path to the ontology index directory
(default: \code{file.path(tools::R_user_dir("basalt", "cache"), "index")}).}

\item{weights}{Named numeric vector mapping relation types to weights.
Defaults cover the standard types.}

\item{symmetric}{Logical. If \code{TRUE} (default), the matrix is made
symmetric by taking \code{max(A[i,j], A[j,i])} for each pair.}
}
\value{
A named square numeric matrix. Row and column names are term IDs.
}
\description{
Build weighted adjacency matrices and cluster terms using
  base R graph tools.
Build a weighted adjacency matrix from the ontology index

Constructs a square numeric matrix where entry \code{[i,j]} is the weight
of the strongest relation from term \code{i} to term \code{j}. Only terms
that appear in at least one relation are included.
}
