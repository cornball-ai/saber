#' @title Add terms and relations programmatically
#' @description Bulk-insert terms and relations into the ontology, with
#'   optional persistent annotation files.

#' Add terms and relations to the ontology
#'
#' Insert terms and/or relations directly into the SQLite index. Optionally
#' writes a markdown annotation file to persist additions across re-indexes.
#'
#' @param terms Character vector of term names to add.
#' @param relations A data.frame with columns: subject, relation_type, object.
#' @param db_path Path to the SQLite database.
#' @param vault_path Path to the vault (used to derive db_path if db_path is NULL).
#' @param annotations_dir Directory for persistent annotation files. Set to
#'   NULL to skip writing annotations. Default: \code{~/.cache/basalt/annotations}.
#' @return A list with counts of terms and relations added (invisibly).
#' @export
add <- function(terms = NULL, relations = NULL,
                    db_path = NULL, vault_path = NULL,
                    annotations_dir = file.path(path.expand("~"),
                                                ".cache", "basalt",
                                                "annotations")) {
  db <- resolve_db(db_path, vault_path)
  con <- db_connect(db)
  on.exit(RSQLite::dbDisconnect(con))

  n_terms <- 0L
  n_rels <- 0L

  # Insert terms
  if (!is.null(terms) && length(terms) > 0L) {
    for (t in terms) {
      res <- RSQLite::dbExecute(con,
        "INSERT OR IGNORE INTO terms (id, name, promoted, updated_at)
         VALUES (?, ?, 0, strftime('%Y-%m-%dT%H:%M:%S', 'now'))",
        params = list(t, t))
      n_terms <- n_terms + res
    }
  }

  # Insert relations
  if (!is.null(relations) && nrow(relations) > 0L) {
    expected <- c("subject", "relation_type", "object")
    if (!all(expected %in% names(relations))) {
      stop("relations must have columns: subject, relation_type, object")
    }
    for (i in seq_len(nrow(relations))) {
      # Ensure subject and object exist as terms
      RSQLite::dbExecute(con,
        "INSERT OR IGNORE INTO terms (id, name, promoted, updated_at)
         VALUES (?, ?, 0, strftime('%Y-%m-%dT%H:%M:%S', 'now'))",
        params = list(relations$subject[i], relations$subject[i]))
      RSQLite::dbExecute(con,
        "INSERT OR IGNORE INTO terms (id, name, promoted, updated_at)
         VALUES (?, ?, 0, strftime('%Y-%m-%dT%H:%M:%S', 'now'))",
        params = list(relations$object[i], relations$object[i]))

      res <- RSQLite::dbExecute(con,
        "INSERT OR IGNORE INTO relations
           (subject_id, relation_type, object_id, confirmed, source)
         VALUES (?, ?, ?, 1, 'manual')",
        params = list(relations$subject[i], relations$relation_type[i],
                      relations$object[i]))
      n_rels <- n_rels + res
    }
  }

  # Write persistent annotation file
  if (!is.null(annotations_dir)) {
    write_annotation(annotations_dir, terms, relations)
  }

  message(sprintf("Added %d term(s), %d relation(s)", n_terms, n_rels))
  invisible(list(terms = n_terms, relations = n_rels))
}

#' Write an annotation markdown file to persist additions
#' @noRd
write_annotation <- function(annotations_dir, terms, relations) {
  dir.create(annotations_dir, recursive = TRUE, showWarnings = FALSE)

  timestamp <- format(Sys.time(), "%Y%m%d-%H%M%S")
  outfile <- file.path(annotations_dir, paste0("add-", timestamp, ".md"))

  lines <- c(
    "---",
    "source: basalt::add",
    sprintf("created: %s", Sys.time()),
    "---"
  )

  if (!is.null(terms) && length(terms) > 0L) {
    lines <- c(lines, "", "## Terms", "")
    for (t in terms) {
      lines <- c(lines, sprintf("- %s", t))
    }
  }

  if (!is.null(relations) && nrow(relations) > 0L) {
    lines <- c(lines, "", "## Relations", "")
    for (i in seq_len(nrow(relations))) {
      lines <- c(lines, sprintf("- %s %s %s",
                                relations$subject[i],
                                relations$relation_type[i],
                                relations$object[i]))
    }
  }

  writeLines(lines, outfile)
  outfile
}
