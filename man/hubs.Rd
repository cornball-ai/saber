% tinyrox says don't edit this manually, but it can't stop you!
\name{hubs}
\alias{hubs}
\title{List all feature hubs}
\usage{
hubs(hubs_dir = file.path(path.expand("~"), ".cache", "basalt", "hubs"))
}
\arguments{
\item{hubs_dir}{Directory containing hub files.}
}
\value{
A data.frame with columns: name, file, links (comma-separated
  wikilink targets).
}
\description{
Returns a data.frame of hub files with their wikilink references.
}
