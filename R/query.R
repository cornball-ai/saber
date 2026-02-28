#' @title Query the ontology graph
#' @description Traverse typed relations in the ontology index.

#' Query the ontology graph
#'
#' Traverse typed relations starting from a term. Supports ancestor,
#' descendant, and sibling traversal.
#'
#' @param term Term name or ID to start from.
#' @param relation Relation type to traverse (e.g., "is_a", "part_of").
#' @param direction One of "ancestors", "descendants", or "siblings".
#' @param db_path Path to the SQLite database. If NULL, not usable.
#' @param vault_path Path to the vault (used to derive db_path if db_path is NULL).
#' @return A data.frame with columns: id, name, distance.
#' @export
ont_query <- function(term, relation, direction = c("ancestors", "descendants",
                                                     "siblings"),
                      db_path = NULL, vault_path = NULL) {
  direction <- match.arg(direction)
  db <- resolve_db(db_path, vault_path)
  con <- db_connect(db)
  on.exit(RSQLite::dbDisconnect(con))

  term_id <- resolve_term(con, term)
  if (is.na(term_id)) {
    stop("Term not found: ", term)
  }

  switch(direction,
    ancestors = traverse_ancestors(con, term_id, relation),
    descendants = traverse_descendants(con, term_id, relation),
    siblings = find_siblings(con, term_id, relation)
  )
}

#' Resolve a term name or alias to its ID
#' @noRd
resolve_term <- function(con, term) {
  # Try exact ID match
  row <- RSQLite::dbGetQuery(con, "SELECT id FROM terms WHERE id = ?",
                             params = list(term))
  if (nrow(row) > 0L) return(row$id[1L])

  # Try name match
  row <- RSQLite::dbGetQuery(con, "SELECT id FROM terms WHERE name = ?",
                             params = list(term))
  if (nrow(row) > 0L) return(row$id[1L])

  # Try alias match (search JSON array)
  all_terms <- RSQLite::dbGetQuery(con, "SELECT id, aliases FROM terms")
  for (i in seq_len(nrow(all_terms))) {
    aliases <- tryCatch(
      jsonlite_parse(all_terms$aliases[i]),
      error = function(e) character(0L)
    )
    if (term %in% aliases) return(all_terms$id[i])
  }

  NA_character_
}

#' Parse a JSON array string without jsonlite
#' @noRd
jsonlite_parse <- function(x) {
  if (is.na(x) || x == "[]") return(character(0L))
  # Simple JSON array parser for string arrays
  x <- sub("^\\[\\s*", "", x)
  x <- sub("\\s*\\]$", "", x)
  if (nchar(x) == 0L) return(character(0L))
  parts <- strsplit(x, ",")[[1L]]
  trimws(gsub('"', '', parts))
}

#' Traverse ancestors (walk up the graph)
#' @noRd
traverse_ancestors <- function(con, term_id, relation) {
  visited <- character(0L)
  frontier <- term_id
  distance <- 0L
  results <- data.frame(id = character(0L), name = character(0L),
                        distance = integer(0L), stringsAsFactors = FALSE)

  while (length(frontier) > 0L) {
    distance <- distance + 1L
    placeholders <- paste(rep("?", length(frontier)), collapse = ", ")
    parents <- RSQLite::dbGetQuery(con, sprintf(
      "SELECT r.object_id AS id, t.name
       FROM relations r
       LEFT JOIN terms t ON r.object_id = t.id
       WHERE r.subject_id IN (%s) AND r.relation_type = ? AND r.confirmed = 1",
      placeholders),
      params = c(as.list(frontier), list(relation)))

    if (nrow(parents) == 0L) break
    parents <- parents[!parents$id %in% visited, , drop = FALSE]
    if (nrow(parents) == 0L) break

    parents$distance <- distance
    results <- rbind(results, parents)
    visited <- c(visited, parents$id)
    frontier <- parents$id
  }

  results
}

#' Traverse descendants (walk down the graph)
#' @noRd
traverse_descendants <- function(con, term_id, relation) {
  visited <- character(0L)
  frontier <- term_id
  distance <- 0L
  results <- data.frame(id = character(0L), name = character(0L),
                        distance = integer(0L), stringsAsFactors = FALSE)

  while (length(frontier) > 0L) {
    distance <- distance + 1L
    placeholders <- paste(rep("?", length(frontier)), collapse = ", ")
    children <- RSQLite::dbGetQuery(con, sprintf(
      "SELECT r.subject_id AS id, t.name
       FROM relations r
       LEFT JOIN terms t ON r.subject_id = t.id
       WHERE r.object_id IN (%s) AND r.relation_type = ? AND r.confirmed = 1",
      placeholders),
      params = c(as.list(frontier), list(relation)))

    if (nrow(children) == 0L) break
    children <- children[!children$id %in% visited, , drop = FALSE]
    if (nrow(children) == 0L) break

    children$distance <- distance
    results <- rbind(results, children)
    visited <- c(visited, children$id)
    frontier <- children$id
  }

  results
}

#' Find siblings (terms sharing the same parent via a relation)
#' @noRd
find_siblings <- function(con, term_id, relation) {
  # Find parents
  parents <- RSQLite::dbGetQuery(con,
    "SELECT object_id FROM relations
     WHERE subject_id = ? AND relation_type = ? AND confirmed = 1",
    params = list(term_id, relation))

  if (nrow(parents) == 0L) {
    return(data.frame(id = character(0L), name = character(0L),
                      parent = character(0L), stringsAsFactors = FALSE))
  }

  placeholders <- paste(rep("?", nrow(parents)), collapse = ", ")
  siblings <- RSQLite::dbGetQuery(con, sprintf(
    "SELECT r.subject_id AS id, t.name, r.object_id AS parent
     FROM relations r
     LEFT JOIN terms t ON r.subject_id = t.id
     WHERE r.object_id IN (%s) AND r.relation_type = ?
       AND r.confirmed = 1 AND r.subject_id != ?",
    placeholders),
    params = c(as.list(parents$object_id), list(relation, term_id)))

  siblings
}

#' Resolve db_path from arguments
#' @noRd
resolve_db <- function(db_path, vault_path) {
  if (!is.null(db_path)) return(db_path)
  if (!is.null(vault_path)) return(db_path(vault_path))
  stop("Either db_path or vault_path must be provided.")
}
