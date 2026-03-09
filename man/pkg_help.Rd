% tinyrox says don't edit this manually, but it can't stop you!
\name{pkg_help}
\alias{pkg_help}
\title{Get help for a package topic as markdown}
\usage{
pkg_help(topic, package, format = c("md", "hugo"))
}
\arguments{
\item{topic}{Character. The help topic name.}

\item{package}{Character. Package name.}

\item{format}{Character. Output format: \code{"md"} (default) for plain
markdown, or \code{"hugo"} for Hugo-compatible markdown with YAML front
matter.}
}
\value{
Character string of markdown help text.
}
\description{
Extracts help documentation and converts it to clean markdown.
}
