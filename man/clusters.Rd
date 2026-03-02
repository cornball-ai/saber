% tinyrox says don't edit this manually, but it can't stop you!
\name{clusters}
\alias{clusters}
\title{Cluster terms using hierarchical clustering}
\usage{
clusters(vault_path = file.path(tools::R_user_dir("basalt", "cache"), "index"),
         k = NULL,
         weights = c(depends = 1, imports = 1, links_to = 0.8, suggests = 0.3, is_a = 0.5, part_of = 0.5, uses = 1),
         method = "ward.D2")
}
\arguments{
\item{vault_path}{Path to the ontology index directory
(default: \code{file.path(tools::R_user_dir("basalt", "cache"), "index")}).}

\item{k}{Number of clusters. If \code{NULL}, a silhouette-like heuristic
is used to pick \code{k} automatically.}

\item{weights}{Named numeric vector of relation type weights, passed to
\code{\link{adjacency}}.}

\item{method}{Agglomeration method for \code{\link{hclust}}.
Default \code{"ward.D2"}.}
}
\value{
A data.frame with columns \code{term} and \code{cluster}.
}
\description{
Builds a weighted adjacency matrix and applies \code{\link{hclust}} to
find groups of related terms. Uses base R only — no igraph needed.
}
