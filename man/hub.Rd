% tinyrox says don't edit this manually, but it can't stop you!
\name{hub}
\alias{hub}
\title{Feature hubs}
\usage{
hub(name, content,
    hubs_dir = file.path(tools::R_user_dir("basalt", "cache"), "hubs"))
}
\arguments{
\item{name}{Character. Hub name (used as filename).}

\item{content}{Character. Markdown content for the hub.}

\item{hubs_dir}{Directory for hub files.}
}
\value{
The file path (invisibly).
}
\description{
Markdown files mapping concepts to code via wikilinks.
Create or update a feature hub

Writes a markdown file to \code{~/.cache/basalt/hubs/} that maps a concept
to code locations using \code{[[project::function]]} wikilinks.
}
