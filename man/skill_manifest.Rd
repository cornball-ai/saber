% tinyrox says don't edit this manually, but it can't stop you!
\name{skill_manifest}
\alias{skill_manifest}
\title{Discover package and personal instruction skills}
\usage{
skill_manifest(
  packages = NULL,
  lib.loc = .libPaths(),
  project_dirs = character(),
  roots = character(),
  prefer = c("source", "installed"),
  disabled = character()
)
}
\arguments{
\item{packages}{Installed package names to inspect. NULL scans all packages
in lib.loc; character() skips installed packages.}

\item{lib.loc}{R library directories, in precedence order.}

\item{project_dirs}{Explicit package checkout directories (not scan roots).}

\item{roots}{Optional named character vector of non-package skill roots.}

\item{prefer}{Package source precedence, either source or installed first.}

\item{disabled}{Exact package-qualified or root-qualified skill ids to omit.}
}
\value{
A saber_skill_manifest with entries, roots, resource fingerprints,
  and diagnostics. Printing exposes metadata only, never instruction bodies.
}
\description{
Builds a read-only inventory without loading packages, executing skills,
changing registrations, or writing a cache. Flat package bundles and the
older package-nested layout are both supported.
}
\details{
Package ids have the form package:NAME/SKILL; configured roots use
root:NAME/SKILL. Package selection is whole-root: the preferred origin wins,
then the first explicit checkout or library. A partial source bundle does
not borrow skills from a different installed version. Ambiguous skill names
within the selected root are excluded with diagnostics, not overwritten.

Discovery reads single-line, quoted, and folded/literal name/description
frontmatter. It is not a general YAML parser and never evaluates metadata.
Supporting files are fingerprinted for later drift checks; MD5 fingerprints
detect changes, not authenticity. Hidden files are not instruction resources.
Symlinks within a root are followed once; escapes are refused. No assumption
is made about a user's home directory or personal skill layout.

Existing agent context APIs and native skill registrations are unchanged.
Feed selected metadata to the consumer's catalog and use skill_read() for
on-demand instruction retrieval; discovery alone does not register tools.
}
\examples{
m <- skill_manifest(packages = character(), lib.loc = character())
print(m)
}
