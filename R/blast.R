#' @title Blast radius analysis
#' @description Find all callers of a function across projects.

#' Find callers of a function across projects
#'
#' Given a function name and project, finds all internal callers within that
#' project and all callers in downstream projects (projects whose DESCRIPTION
#' lists this one in Depends, Imports, or LinkingTo).
#'
#' @param fn Character. Function name to search for.
#' @param project Character. Project name (or path to project directory).
#' @param scan_dir Directory to scan for downstream projects.
#' @param cache_dir Directory for symbol cache files.
#' @param exclude Character vector of directory basenames to skip when
#'   scanning for downstream projects.
#' @return A data.frame with columns: caller, project, file, line.
#' @examples
#' # Create a minimal project
#' d <- file.path(tempdir(), "blastpkg")
#' dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
#' writeLines("helper <- function(x) x + 1", file.path(d, "R", "helper.R"))
#' writeLines("main <- function(x) helper(x * 2)", file.path(d, "R", "main.R"))
#'
#' # Find all callers of helper()
#' blast_radius("helper", project = d, scan_dir = tempdir(),
#'              cache_dir = tempdir())
#' @export
blast_radius <- function(fn, project = NULL,
                         scan_dir = path.expand("~"),
                         cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols"),
                         exclude = default_exclude()) {
    if (is.null(project)) {
        project <- basename(getwd())
    }

    # Resolve project directory
    project_dir <- project
    if (!dir.exists(file.path(project, "R"))) {
        project_dir <- file.path(path.expand("~"), project)
    }
    project_name <- basename(normalizePath(project_dir, mustWork = FALSE))

    results <- data.frame(caller = character(), project = character(),
                          file = character(), line = integer(),
                          stringsAsFactors = FALSE)

    # 1. Internal callers from this project's symbol cache
    if (dir.exists(project_dir)) {
        syms <- symbols(project_dir, cache_dir = cache_dir)
        internal <- syms$calls[syms$calls$callee == fn,, drop = FALSE]
        if (nrow(internal) > 0L) {
            results <- rbind(results,
                             data.frame(caller = internal$caller, project = project_name,
                                        file = internal$file, line = internal$line,
                                        stringsAsFactors = FALSE))
        }
    }

    # 2. Find downstream projects via DESCRIPTION files
    downstream <- find_downstream(project_name, scan_dir, exclude)

    for (ds_name in downstream) {
        ds_dir <- file.path(scan_dir, ds_name)
        if (!dir.exists(file.path(ds_dir, "R"))) {
            next
        }

        ds_syms <- symbols(ds_dir, cache_dir = cache_dir)
        # Look for pkg::fn calls and bare fn calls
        qualified <- paste0(project_name, "::", fn)
        ds_callers <- ds_syms$calls[ds_syms$calls$callee == qualified |
            ds_syms$calls$callee == fn,, drop = FALSE]
        if (nrow(ds_callers) > 0L) {
            results <- rbind(results,
                             data.frame(caller = ds_callers$caller, project = ds_name,
                    file = ds_callers$file, line = ds_callers$line,
                    stringsAsFactors = FALSE))
        }
    }

    results
}
