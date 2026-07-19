% tinyrox says don't edit this manually, but it can't stop you!
\name{src_symbols}
\alias{src_symbols}
\title{Build a symbol index for a project's non-R sources}
\usage{
src_symbols(project_dir, langs = c("c", "cpp", "python", "rust", "javascript"),
            exclude = default_src_exclude(),
            cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols"))
}
\arguments{
\item{project_dir}{Path to the project directory.}

\item{langs}{Character vector of languages to index. Any of \code{"c"},
\code{"cpp"}, \code{"python"}, \code{"rust"}, \code{"javascript"}
(all five by default).}

\item{exclude}{Character vector of directory basenames to skip while
scanning, e.g. vendored or generated trees. The default
\code{\link{default_src_exclude}} includes the
\code{\link{default_exclude}} opt-outs, so user directories such as
\code{Documents} stay untouched even when scanning from a home
directory.}

\item{cache_dir}{Directory for symbol cache files.}
}
\value{
A list with components:
  \describe{
    \item{defs}{data.frame(name, file, line, lang, exported)}
    \item{calls}{data.frame(caller, callee, file, line, lang)}
  }
}
\description{
Recursively scans \code{project_dir} for C (\code{.c}, \code{.h}), C++
(\code{.cc}, \code{.cpp}, \code{.cxx}, \code{.hh}, \code{.hpp}), Python
(\code{.py}), Rust (\code{.rs}), and JavaScript (\code{.js},
\code{.mjs}, \code{.cjs}, \code{.jsx}) sources and parses them into
function definitions and call relationships, mirroring the shape of
\code{\link{symbols}} with an added \code{lang} column. This covers the
\code{src/} directory of an R package as well as repositories that are
not R packages at all. Directories named in \code{exclude} are skipped,
as are hidden directories and \code{*.Rcheck} directories, always.
Results are cached as RDS in the user cache directory alongside the
\code{symbols()} cache.
}
\details{
A definition is marked \code{exported} when it is visible beyond its own
file or module: for C/C++, definitions not declared \code{static}; for
Python, names without a leading underscore; for Rust, items declared
\code{pub}; for JavaScript, definitions wrapped in an \code{export}
statement.

Parsing uses the suggested \pkg{bonsaisitter} tree-sitter runtime with
one grammar package per language: \pkg{treesitter.c} for C (falling back
to \pkg{treesitter.cpp}, which also parses C), \pkg{treesitter.cpp} for
C++, \pkg{treesitter.python} for Python, \pkg{treesitter.rust} for Rust,
and \pkg{treesitter.javascript} for JavaScript. Grammars are only
required for languages that actually match files, and projects with no
matching files return empty indices without requiring any of them.

}
\examples{
# Needs the bonsaisitter runtime; also needs a grammar package per
# language, tolerated via tryCatch() so the example survives its absence
if (requireNamespace("bonsaisitter", quietly = TRUE)) {

    # Create a minimal project with a src/ directory
    d <- file.path(tempdir(), "srcdemo")
    dir.create(file.path(d, "src"), recursive = TRUE, showWarnings = FALSE)
    writeLines(c(
        "static double square(double x) { return x * x; }",
        "double area(double r) { return 3.14159 * square(r); }"
    ), file.path(d, "src", "area.c"))

    idx <- tryCatch(src_symbols(d, cache_dir = tempdir()),
                    error = function(e) NULL)
    idx$defs   # C function definitions
    idx$calls  # call relationships (area calls square)
}
}
