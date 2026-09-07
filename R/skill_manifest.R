#' Discover package and personal instruction skills
#'
#' Builds a read-only inventory without loading packages, executing skills,
#' changing registrations, or writing a cache. Flat package bundles and the
#' older package-nested layout are both supported.
#'
#' @param packages Installed package names to inspect. NULL scans all packages
#'   in lib.loc; character() skips installed packages.
#' @param lib.loc R library directories, in precedence order.
#' @param project_dirs Explicit package checkout directories (not scan roots).
#' @param roots Optional named character vector of non-package skill roots.
#' @param prefer Package source precedence, either source or installed first.
#' @param disabled Exact package-qualified or root-qualified skill ids to omit.
#' @return A saber_skill_manifest with entries, roots, resource fingerprints,
#'   and diagnostics. Printing exposes metadata only, never instruction bodies.
#' @details
#' Package ids have the form package:NAME/SKILL; configured roots use
#' root:NAME/SKILL. Package selection is whole-root: the preferred origin wins,
#' then the first explicit checkout or library. A partial source bundle does
#' not borrow skills from a different installed version. Ambiguous skill names
#' within the selected root are excluded with diagnostics, not overwritten.
#'
#' Discovery reads single-line, quoted, and folded/literal name/description
#' frontmatter. It is not a general YAML parser and never evaluates metadata.
#' Supporting files are fingerprinted for later drift checks; MD5 fingerprints
#' detect changes, not authenticity. Hidden files are not instruction resources.
#' Symlinks within a root are followed once; escapes are refused. No assumption
#' is made about a user's home directory or personal skill layout.
#'
#' Existing agent context APIs and native skill registrations are unchanged.
#' Feed selected metadata to the consumer's catalog and use skill_read() for
#' on-demand instruction retrieval; discovery alone does not register tools.
#' @examples
#' m <- skill_manifest(packages = character(), lib.loc = character())
#' print(m)
#' @export
skill_manifest <- function(packages = NULL, lib.loc = .libPaths(),
                           project_dirs = character(), roots = character(),
                           prefer = c("source", "installed"),
                           disabled = character()) {
    prefer <- match.arg(prefer)
    prefer <- c(prefer, setdiff(c("source", "installed"), prefer))
    for (x in list(packages, lib.loc, project_dirs, roots, disabled)) {
        if (!is.null(x) && (!is.character(x) || anyNA(x) || any(!nzchar(x)))) {
            stop("Skill paths, packages and ids must be nonempty strings.",
                 call. = FALSE)
        }
    }
    if (length(roots) &&
        (is.null(names(roots)) || anyDuplicated(names(roots)) ||
            any(!grepl("^[A-Za-z0-9][A-Za-z0-9._-]*$", names(roots))))) {
        stop("Skill roots require unique stable names.", call. = FALSE)
    }
    source <- skill_roots(packages, lib.loc, project_dirs, roots, prefer)
    entries <- skill_empty_entries()
    diagnostics <- data.frame(path = character(), reason = character())
    for (i in seq_len(nrow(source))) {
        paths <- tryCatch(skill_walk(source$path[i], bundles = TRUE),
                          error = function(e) e)
        if (inherits(paths, "error")) {
            diagnostics <- rbind(diagnostics, data.frame(path = source$path[i],
                    reason = conditionMessage(paths)))
            next
        }
        for (path in paths) {
            item <- tryCatch(skill_entry(path, source[i,]), error = function(e) e)
            if (inherits(item, "error")) {
                diagnostics <- rbind(diagnostics, data.frame(path = path,
                        reason = conditionMessage(item)))
            } else entries <- rbind(entries, item)
        }
    }
    selected <- which(entries$selected)
    ids <- entries$id[selected]
    ambiguous <- ids[duplicated(ids) | duplicated(ids, fromLast = TRUE)]
    entries$reason[entries$id %in% ambiguous &
        entries$selected] <- "duplicate_id"
    entries$selected[entries$id %in% ambiguous] <- FALSE
    entries$reason[entries$id %in% disabled] <- "disabled"
    entries$selected[entries$id %in% disabled] <- FALSE
    result <- skill_inventory(entries, diagnostics)
    structure(c(list(schema_version = 1L, roots = source), result),
              class = "saber_skill_manifest")
}

skill_empty_entries <- function() {
    data.frame(id = character(), name = character(),
               description = character(), package = character(),
               version = character(), origin = character(),
               root = character(), path = character(), selected = logical(),
               reason = character())
}

skill_entry <- function(path, source) {
    metadata <- skill_metadata(file.path(path, "SKILL.md"))
    data.frame(id = paste0(source$owner, "/", metadata$name),
               name = metadata$name, description = metadata$description,
               package = source$package, version = source$version,
               origin = source$origin, root = source$path,
               path = normalizePath(path, winslash = "/", mustWork = TRUE),
               selected = source$selected,
               reason = if (source$selected) "selected" else "shadowed_root",
               stringsAsFactors = FALSE)
}

skill_inventory <- function(entries, diagnostics) {
    resources <- list()
    for (i in which(entries$selected)) {
        snapshot <- tryCatch(skill_snapshot(entries$path[i]),
                             error = function(e) e)
        if (inherits(snapshot, "error")) {
            entries$selected[i] <- FALSE
            entries$reason[i] <- "unreadable_resources"
            diagnostics <- rbind(diagnostics, data.frame(path = entries$path[i],
                    reason = conditionMessage(snapshot)))
        } else resources[[entries$id[i]]] <- snapshot
    }
    list(entries = entries, resources = resources, diagnostics = diagnostics)
}

#' @export
print.saber_skill_manifest <- function(x, ...) {
    cat(sprintf("Skill manifest: %d selected / %d candidates\n",
                sum(x$entries$selected), nrow(x$entries)))
    print(x$entries[, c("id", "origin", "version", "selected", "reason"), drop = FALSE],
          row.names = FALSE)
    if (nrow(x$diagnostics)) print(x$diagnostics, row.names = FALSE)
    invisible(x)
}
