% tinyrox says don't edit this manually, but it can't stop you!
\name{graph_svg}
\alias{graph_svg}
\title{Force-directed graph rendering}
\usage{
graph_svg(edges, nodes = NULL, width = 1200L, height = 900L, iterations = 50L,
          seed = 1L)
}
\arguments{
\item{edges}{Data frame with \code{from} and \code{to} columns
holding node ids.}

\item{nodes}{Optional data frame with \code{id}, \code{label},
\code{href} columns. Optionally a \code{tooltip} column (plain
text, may contain newlines) that overrides the default hover
text (which is the label). \code{id} must cover every node
mentioned in \code{edges}. If \code{NULL}, ids from \code{edges}
are used as labels with no hrefs or tooltips.}

\item{width}{SVG viewport width in pixels.}

\item{height}{SVG viewport height in pixels.}

\item{iterations}{Force-simulation steps. 50 is usually enough.}

\item{seed}{Integer seed for the random initial layout (output is
deterministic given the same seed).}
}
\value{
Character vector, one SVG element per line. Write with
  \code{writeLines()}.
}
\description{
Render a graph as static, interactive SVG using a base R
  Fruchterman-Reingold force simulation.
Render a graph as static SVG

Runs a Fruchterman-Reingold force simulation to lay out nodes, then
emits SVG with baked coordinates. Output is interactive via native
browser features: hover tooltips from \code{<title>} elements, click
navigation from \code{<a xlink:href>} wrappers, CSS \code{:hover}
highlighting. No JavaScript.

Suitable for graphs up to roughly a few hundred nodes. The repulsion
step is vectorized via \code{outer()} but allocates an
\code{n x n} matrix per iteration; larger graphs should pre-filter.
}
\examples{
edges <- data.frame(from = c("a", "a", "b"),
                    to = c("b", "c", "c"))
svg <- graph_svg(edges)
writeLines(svg, tempfile(fileext = ".svg"))
}
