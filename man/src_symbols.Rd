% tinyrox says don't edit this manually, but it can't stop you!
\name{src_symbols}
\alias{src_symbols}
\title{Build a symbol index for a project's src/ directory}
\usage{
src_symbols(project_dir,
            cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols"))
}
\arguments{
\item{project_dir}{Path to the project directory.}

\item{cache_dir}{Directory for symbol cache files.}
}
\value{
A list with components:
  \describe{
    \item{defs}{data.frame(name, file, line, exported)}
    \item{calls}{data.frame(caller, callee, file, line)}
  }
}
\description{
Parses top-level \code{src/} C and C++ files (\code{.c}, \code{.cc},
\code{.cpp}, \code{.h}, \code{.hpp}) into function definitions and call
relationships, mirroring the shape of \code{\link{symbols}}. Vendored
code in \code{src/} subdirectories is not scanned. Results are cached as
RDS in the user cache directory alongside the \code{symbols()} cache.
}
\details{
A definition is marked \code{exported} when its name appears in an R
registration table (\code{R_CallMethodDef}, \code{R_CMethodDef},
\code{R_FortranMethodDef}, \code{R_ExternalMethodDef}), meaning it is
reachable from R via \code{.Call()} and friends.

Parsing uses the suggested \pkg{bonsaisitter} tree-sitter runtime with the
\pkg{treesitter.cpp} grammar package; both must be installed. Projects
without a \code{src/} directory return empty indices without requiring
either package.

}
\examples{
if (requireNamespace("bonsaisitter", quietly = TRUE) &&
    requireNamespace("treesitter.cpp", quietly = TRUE)) {

    # Create a minimal project with a src/ directory
    d <- file.path(tempdir(), "srcdemo")
    dir.create(file.path(d, "src"), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(
        "static double square(double x) { return x * x; }",
        "double area(double r) { return 3.14159 * square(r); }"
    ), file.path(d, "src", "area.c"))

    idx <- src_symbols(d, cache_dir = tempdir())
    idx$defs   # C function definitions
    idx$calls  # call relationships (area calls square)
}
}
