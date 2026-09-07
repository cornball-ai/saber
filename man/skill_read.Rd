% tinyrox says don't edit this manually, but it can't stop you!
\name{skill_read}
\alias{skill_read}
\title{Read an instruction from a skill manifest}
\usage{
skill_read(manifest, id, resource = "SKILL.md")
}
\arguments{
\item{manifest}{A skill_manifest() result for the current session.}

\item{id}{Exact selected skill id, including its package or root namespace.}

\item{resource}{Relative resource path within that skill, default SKILL.md.}
}
\value{
One character string, without a wrapper or whitespace normalization.
}
\description{
Returns the exact UTF-8 file text after checking its recorded identity and
fingerprint. Supporting resources receive the same checks as SKILL.md.
}
\details{
Only resources inventoried in this manifest are readable. Absolute paths,
parent traversal, changed files, and symlink escapes are refused. Rebuild the
manifest explicitly to accept changed source instructions. This reader does
not execute scripts or grant tool permissions. Binary/NUL-containing files
and files larger than 1 MiB are refused by this text interface.
}
\examples{
m <- skill_manifest(packages = character(), lib.loc = character())
nrow(m$entries)
}
