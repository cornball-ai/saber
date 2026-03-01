#' @title Blast radius analysis
#' @description Find all callers of a function across projects.

#' Find callers of a function across projects
#'
#' Given a function name and project, finds all internal callers within that
#' project and all callers in downstream projects (projects that \code{uses}
#' this one according to the ontology).
#'
#' @param fn Character. Function name to search for.
#' @param project Character. Project name (or path to project directory).
#' @param vault_path Path to the basalt vault (for ontology lookups).
#' @param cache_dir Directory for symbol cache files.
#' @return A data.frame with columns: caller, project, file, line.
#' @export
blast_radius <- function(fn, project = NULL,
                         vault_path = file.path(path.expand("~"),
                                                ".cache", "basalt", "vault"),
                         cache_dir = file.path(path.expand("~"),
                                               ".cache", "basalt", "symbols")) {
  if (is.null(project)) project <- basename(getwd())

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
    internal <- syms$calls[syms$calls$callee == fn, , drop = FALSE]
    if (nrow(internal) > 0L) {
      results <- rbind(results, data.frame(
        caller = internal$caller,
        project = project_name,
        file = internal$file,
        line = internal$line,
        stringsAsFactors = FALSE
      ))
    }
  }

  # 2. Find downstream projects via ontology `uses` relations
  db <- tryCatch(resolve_db(NULL, vault_path), error = function(e) NULL)
  if (!is.null(db) && file.exists(db)) {
    con <- tryCatch(db_connect(db), error = function(e) NULL)
    if (!is.null(con)) {
      on.exit(RSQLite::dbDisconnect(con))

      # Find projects that `uses` this project
      downstream <- RSQLite::dbGetQuery(con,
        "SELECT subject_id FROM relations
         WHERE object_id = ? AND relation_type = 'uses' AND confirmed = 1",
        params = list(project_name))

      for (ds_name in downstream$subject_id) {
        ds_dir <- file.path(path.expand("~"), ds_name)
        if (!dir.exists(ds_dir)) next

        ds_syms <- symbols(ds_dir, cache_dir = cache_dir)
        # Look for pkg::fn calls
        qualified <- paste0(project_name, "::", fn)
        ds_callers <- ds_syms$calls[ds_syms$calls$callee == qualified |
                                    ds_syms$calls$callee == fn, , drop = FALSE]
        if (nrow(ds_callers) > 0L) {
          results <- rbind(results, data.frame(
            caller = ds_callers$caller,
            project = ds_name,
            file = ds_callers$file,
            line = ds_callers$line,
            stringsAsFactors = FALSE
          ))
        }
      }
    }
  }

  results
}
