#' @title Project discovery — package dependency graph
#' @description Render the dependency graph across a set of R packages as
#'   interactive SVG.

#' Render a package-level dependency graph
#'
#' Discovers R packages under \code{scan_dir} via \code{\link{projects}},
#' parses each one's \code{Depends} and \code{Imports} fields, and
#' renders edges between packages that both live in \code{scan_dir}.
#' External CRAN dependencies are dropped.
#'
#' @param scan_dir Directory to scan for project directories.
#' @param packages Optional character vector limiting the graph to
#'   these packages.
#' @param include_suggests If \code{TRUE}, also include edges for
#'   packages in each project's \code{Suggests} field. Default
#'   \code{FALSE} (only \code{Depends} and \code{Imports}).
#' @param ... Passed through to \code{\link{graph_svg}}.
#' @return Character vector of SVG lines. Write with \code{writeLines()}.
#' @examples
#' d <- file.path(tempdir(), "pkgdemo")
#' dir.create(file.path(d, "parent"), recursive = TRUE, showWarnings = FALSE)
#' dir.create(file.path(d, "child"), showWarnings = FALSE)
#' writeLines(c("Package: parent", "Title: P", "Version: 0.1.0"),
#'            file.path(d, "parent", "DESCRIPTION"))
#' writeLines(c("Package: child", "Title: C", "Version: 0.1.0",
#'              "Imports: parent"),
#'            file.path(d, "child", "DESCRIPTION"))
#' svg <- pkg_graph(scan_dir = d)
#' writeLines(svg, tempfile(fileext = ".svg"))
#' @export
pkg_graph <- function(scan_dir = path.expand("~"), packages = NULL,
                      include_suggests = FALSE, ...) {
    projs <- projects(scan_dir = scan_dir)
    if (!is.null(packages)) {
        projs <- projs[projs$package %in% packages,, drop = FALSE]
    }
    if (nrow(projs) == 0L) {
        stop("No packages found under ", scan_dir)
    }

    known <- projs$package
    edges <- list()
    dep_counts <- integer(nrow(projs))
    local_counts <- integer(nrow(projs))
    for (i in seq_len(nrow(projs))) {
        all_deps <- c(parse_deps(projs$depends[i]),
                      parse_deps(projs$imports[i]))
        if (include_suggests) {
            all_deps <- c(all_deps, read_suggests(projs$path[i]))
        }
        local <- intersect(all_deps, known)
        dep_counts[i] <- length(unique(all_deps))
        local_counts[i] <- length(local)
        if (length(local)) {
            edges[[i]] <- data.frame(from = projs$package[i], to = local,
                                     stringsAsFactors = FALSE)
        }
    }
    edges <- do.call(rbind, edges)
    if (is.null(edges)) {
        edges <- data.frame(from = character(), to = character(),
                            stringsAsFactors = FALSE)
    }

    tooltips <- sprintf("%s %s\n%s\n%d deps (%d local)",
                        projs$package, projs$version,
                        ifelse(is.na(projs$title) | !nzchar(projs$title),
                               "(no title)", projs$title),
                        dep_counts, local_counts)

    nodes <- data.frame(id = projs$package, label = projs$package,
                        href = NA_character_, tooltip = tooltips,
                        stringsAsFactors = FALSE)

    graph_svg(edges, nodes, ...)
}

#' Read the Suggests field from a package's DESCRIPTION, returning a
#' character vector of package names with version constraints stripped.
#' @noRd
read_suggests <- function(pkg_path) {
    desc_path <- file.path(pkg_path, "DESCRIPTION")
    if (!file.exists(desc_path)) {
        return(character())
    }
    fields <- read.dcf(desc_path, fields = "Suggests")
    parse_deps(fields[1L, "Suggests"])
}

#' Parse a comma-separated dependency field from a DESCRIPTION column,
#' stripping version constraints and whitespace.
#' @noRd
parse_deps <- function(s) {
    if (is.null(s) || is.na(s) || !nzchar(s)) {
        return(character())
    }
    parts <- strsplit(s, ",", fixed = TRUE)[[1L]]
    parts <- sub("\\s*\\(.*\\)\\s*$", "", parts)
    parts <- trimws(parts)
    parts <- parts[parts != "R" & nzchar(parts)]
    parts
}

