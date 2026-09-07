#' @title Project discovery
#' @description Discover R package projects and map their dependency
#'   relationships.

#' Discover R package projects
#'
#' Scans a directory for subdirectories containing a DESCRIPTION file and
#' returns their metadata. Symbolic-link aliases of the same directory are
#' reported once, preferring its non-alias path when present. Separate
#' checkouts remain separate even when they declare the same package name.
#'
#' @param scan_dir Directory to scan for project directories.
#' @param exclude Character vector of directory basenames to skip.
#' @return A data.frame with columns: package, title, version, path, depends,
#'   imports.
#' @examples
#' d <- file.path(tempdir(), "scandir")
#' dir.create(d, showWarnings = FALSE)
#' pkg <- file.path(d, "mypkg")
#' dir.create(pkg, showWarnings = FALSE)
#' writeLines(c("Package: mypkg", "Title: Demo", "Version: 0.1.0"),
#'            file.path(pkg, "DESCRIPTION"))
#' projects(scan_dir = d)
#' @export
projects <- function(scan_dir = path.expand("~"), exclude = default_exclude()) {
    project_dirs <- project_directories(scan_dir, exclude)

    rows <- list()
    for (d in project_dirs) {
        desc_file <- file.path(d, "DESCRIPTION")
        if (!file.exists(desc_file)) {
            next
        }

        dcf <- tryCatch(
                        read.dcf(desc_file,
                                 fields = c("Package", "Title", "Version", "Depends",
                    "Imports", "LinkingTo")),
                        error = function(e) NULL
        )
        if (is.null(dcf) || nrow(dcf) == 0L) {
            next
        }

        pkg_name <- dcf[1L, "Package"]
        if (is.na(pkg_name) || nchar(trimws(pkg_name)) == 0L) {
            next
        }

        rows[[length(rows) + 1L]] <- data.frame(
            package = pkg_name,
            title = na_to_empty(dcf[1L, "Title"]),
            version = na_to_empty(dcf[1L, "Version"]),
            path = d,
            depends = na_to_empty(dcf[1L, "Depends"]),
            imports = na_to_empty(dcf[1L, "Imports"]),
            stringsAsFactors = FALSE
        )
    }

    if (length(rows) == 0L) {
        return(data.frame(package = character(), title = character(),
                          version = character(), path = character(),
                          depends = character(), imports = character(),
                          stringsAsFactors = FALSE))
    }
    do.call(rbind, rows)
}

#' Find projects that depend on a given package
#'
#' Scans DESCRIPTION files in project directories under \code{scan_dir}
#' for Depends, Imports, or LinkingTo fields that reference \code{package}.
#'
#' @param package Character. Package name to search for.
#' @param scan_dir Directory to scan for project directories.
#' @param exclude Character vector of directory basenames to skip.
#' @return Character vector of project names that depend on \code{package}.
#' @examples
#' d <- file.path(tempdir(), "dsdir")
#' dir.create(d, showWarnings = FALSE)
#' pkg <- file.path(d, "child")
#' dir.create(pkg, showWarnings = FALSE)
#' writeLines(c("Package: child", "Version: 0.1.0", "Imports: parent"),
#'            file.path(pkg, "DESCRIPTION"))
#' find_downstream("parent", scan_dir = d)
#' @export
find_downstream <- function(package, scan_dir = path.expand("~"),
                            exclude = default_exclude()) {
    project_dirs <- project_directories(scan_dir, exclude)
    downstream <- character(0L)

    for (d in project_dirs) {
        desc_file <- file.path(d, "DESCRIPTION")
        if (!file.exists(desc_file)) {
            next
        }

        dcf <- tryCatch(
                        read.dcf(desc_file, fields = c("Depends", "Imports", "LinkingTo")),
                        error = function(e) NULL
        )
        if (is.null(dcf) || nrow(dcf) == 0L) {
            next
        }

        deps <- character(0L)
        for (field in c("Depends", "Imports", "LinkingTo")) {
            deps <- c(deps, parse_dcf_list(dcf[1L, field]))
        }
        if (package %in% deps) {
            downstream <- c(downstream, basename(d))
        }
    }

    downstream
}

#' Discover directories once per filesystem identity
#' @noRd
project_directories <- function(scan_dir, exclude) {
    paths <- list.dirs(scan_dir, recursive = FALSE, full.names = TRUE)
    paths <- paths[!basename(paths) %in% exclude]
    canonical <- normalizePath(paths, winslash = "/", mustWork = FALSE)
    requested <- file.path(normalizePath(scan_dir, winslash = "/",
                                         mustWork = FALSE), basename(paths))
    keys <- if (.Platform$OS.type == "windows") tolower(canonical) else canonical
    preference <- order(requested != canonical, seq_along(paths))
    keep <- preference[!duplicated(keys[preference])]
    paths[sort(keep)]
}

#' Replace NA with empty string
#' @noRd
na_to_empty <- function(x) {
    if (is.na(x)) {
        ""
    } else {
        trimws(x)
    }
}

#' Parse a comma-separated DCF field into a clean character vector
#' @noRd
parse_dcf_list <- function(x) {
    if (is.na(x) || nchar(trimws(x)) == 0L) {
        return(character(0L))
    }
    parts <- strsplit(x, ",")[[1L]]
    parts <- trimws(parts)
    parts <- sub("\\s*\\(.*\\)", "", parts)
    parts <- parts[nchar(parts) > 0L]
    parts
}
