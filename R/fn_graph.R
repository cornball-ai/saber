#' @title Code intelligence — function call graph
#' @description Render a project's internal function call graph as interactive
#'   SVG.

#' Render a function call graph for an R project
#'
#' Pulls the AST symbol index via \code{\link{symbols}} and renders
#' internal function-to-function call edges as SVG. External calls
#' (into other packages) are dropped by default.
#'
#' @param project_dir Path to the project directory (an R package root).
#' @param include_external If \code{TRUE}, also include nodes for
#'   functions called from other packages. Default \code{FALSE}.
#' @param ... Passed through to \code{\link{graph_svg}} (e.g.,
#'   \code{width}, \code{height}, \code{iterations}, \code{seed}).
#' @return Character vector of SVG lines. Write with \code{writeLines()}.
#' @examples
#' d <- file.path(tempdir(), "fngdemo")
#' dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
#' writeLines(c("Package: demo", "Version: 0.1.0"),
#'            file.path(d, "DESCRIPTION"))
#' writeLines("add <- function(x, y) x + y", file.path(d, "R", "add.R"))
#' writeLines("double <- function(x) add(x, x)",
#'            file.path(d, "R", "double.R"))
#' svg <- fn_graph(d)
#' writeLines(svg, tempfile(fileext = ".svg"))
#' @export
fn_graph <- function(project_dir, include_external = FALSE, ...) {
    idx <- symbols(project_dir)
    defs <- idx$defs
    calls <- idx$calls

    if (!include_external) {
        calls <- calls[calls$callee %in% defs$name,, drop = FALSE]
    }

    node_ids <- unique(c(defs$name, calls$callee, calls$caller))
    node_ids <- node_ids[!is.na(node_ids) & nzchar(node_ids)]

    edges <- data.frame(from = calls$caller, to = calls$callee,
                        stringsAsFactors = FALSE)
    edges <- unique(edges[!is.na(edges$from) & !is.na(edges$to),, drop = FALSE])

    def_match <- match(node_ids, defs$name)
    file_rel <- defs$file[def_match]
    line <- defs$line[def_match]
    exported <- defs$exported[def_match]
    in_deg <- tabulate(match(edges$to, node_ids), nbins = length(node_ids))
    out_deg <- tabulate(match(edges$from, node_ids), nbins = length(node_ids))
    visibility <- ifelse(is.na(exported), "external",
                         ifelse(exported, "exported", "internal"))
    tooltips <- ifelse(
                       is.na(def_match),
                       sprintf("%s\n(external)\ncalled by %d", node_ids, in_deg),
                       sprintf("%s\n%s:%d\n%s\ncalled by %d | calls %d",
                               node_ids, file_rel, line, visibility, in_deg, out_deg))

    nodes <- data.frame(id = node_ids, label = node_ids,
                        href = NA_character_, tooltip = tooltips,
                        stringsAsFactors = FALSE)

    graph_svg(edges, nodes, ...)
}

