#' @title Ontology status summary
#' @description Summary stats for the ontology index.

#' Get ontology status summary
#'
#' Returns summary statistics about the ontology: term count, relation count,
#' promoted terms, and unconfirmed suggestions.
#'
#' @param db_path Path to the SQLite database.
#' @param vault_path Path to the vault (used to derive db_path if db_path is NULL).
#' @return A list with components: terms, promoted, relations, suggestions,
#'   relation_types.
#' @export
ont_status <- function(db_path = NULL, vault_path = NULL) {
  db <- resolve_db(db_path, vault_path)
  con <- db_connect(db)
  on.exit(RSQLite::dbDisconnect(con))

  n_terms <- RSQLite::dbGetQuery(con, "SELECT COUNT(*) AS n FROM terms")$n
  n_promoted <- RSQLite::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM terms WHERE promoted = 1")$n
  n_relations <- RSQLite::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM relations WHERE confirmed = 1")$n
  n_suggestions <- RSQLite::dbGetQuery(con,
    "SELECT COUNT(*) AS n FROM relations WHERE confirmed = 0")$n
  rel_types <- RSQLite::dbGetQuery(con,
    "SELECT relation_type, COUNT(*) AS n FROM relations
     WHERE confirmed = 1 GROUP BY relation_type")

  result <- list(
    terms = n_terms,
    promoted = n_promoted,
    relations = n_relations,
    suggestions = n_suggestions,
    relation_types = rel_types
  )
  class(result) <- "ont_status"
  result
}

#' @export
print.ont_status <- function(x, ...) {
  cat("Ontology status:\n")
  cat(sprintf("  Terms:       %d (%d promoted)\n", x$terms, x$promoted))
  cat(sprintf("  Relations:   %d confirmed\n", x$relations))
  cat(sprintf("  Suggestions: %d unconfirmed\n", x$suggestions))
  if (nrow(x$relation_types) > 0L) {
    cat("  By type:\n")
    for (i in seq_len(nrow(x$relation_types))) {
      cat(sprintf("    %s: %d\n", x$relation_types$relation_type[i],
                  x$relation_types$n[i]))
    }
  }
  invisible(x)
}
