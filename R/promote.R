#' @title Promote a term with a stable ID
#' @description Write a stable ontology ID into a file's frontmatter.

#' Promote a term with a stable ID
#'
#' Assigns a stable \code{PREFIX:NNNNNNN} identifier to a term by writing
#' it into the markdown file's YAML frontmatter.
#'
#' @param term Term name to promote.
#' @param vault_path Path to the markdown vault directory.
#' @param prefix ID prefix (default "ONTO").
#' @return The new ID (invisibly).
#' @export
ont_promote <- function(term, vault_path, prefix = "ONTO") {
  vault_path <- normalizePath(vault_path, mustWork = TRUE)
  dbfile <- db_path(vault_path)
  con <- db_connect(dbfile)
  on.exit(RSQLite::dbDisconnect(con))

  # Find the term
  row <- RSQLite::dbGetQuery(con,
    "SELECT id, name, filepath, promoted FROM terms WHERE name = ? OR id = ?",
    params = list(term, term))

  if (nrow(row) == 0L) {
    stop("Term not found: ", term)
  }
  if (row$promoted[1L] == 1L) {
    message("Term already promoted with ID: ", row$id[1L])
    return(invisible(row$id[1L]))
  }
  if (is.na(row$filepath[1L])) {
    stop("Term has no source file. Cannot promote a term inferred from links alone.")
  }

  # Generate next ID
  new_id <- next_id(con, prefix)

  # Write ID into frontmatter
  filepath <- file.path(vault_path, row$filepath[1L])
  write_id_to_frontmatter(filepath, new_id)

  # Update index
  old_id <- row$id[1L]
  RSQLite::dbExecute(con,
    "UPDATE terms SET id = ?, promoted = 1,
       updated_at = strftime('%Y-%m-%dT%H:%M:%S', 'now')
     WHERE id = ?",
    params = list(new_id, old_id))

  # Update relations referencing old ID

RSQLite::dbExecute(con,
    "UPDATE relations SET subject_id = ? WHERE subject_id = ?",
    params = list(new_id, old_id))
  RSQLite::dbExecute(con,
    "UPDATE relations SET object_id = ? WHERE object_id = ?",
    params = list(new_id, old_id))

  message("Promoted '", row$name[1L], "' -> ", new_id)
  invisible(new_id)
}

#' Generate the next ID
#' @noRd
next_id <- function(con, prefix) {
  existing <- RSQLite::dbGetQuery(con,
    "SELECT id FROM terms WHERE id LIKE ? AND promoted = 1",
    params = list(paste0(prefix, ":%")))

  if (nrow(existing) == 0L) {
    return(sprintf("%s:%07d", prefix, 1L))
  }

  nums <- as.integer(sub("^[^:]+:", "", existing$id))
  nums <- nums[!is.na(nums)]
  next_num <- if (length(nums) == 0L) 1L else max(nums) + 1L
  sprintf("%s:%07d", prefix, next_num)
}

#' Write an id field into YAML frontmatter
#' @noRd
write_id_to_frontmatter <- function(filepath, id) {
  lines <- readLines(filepath, warn = FALSE)

  if (length(lines) < 2L || trimws(lines[1L]) != "---") {
    # No frontmatter: add it
    lines <- c("---", paste0("id: ", id), "---", lines)
  } else {
    end <- which(trimws(lines[-1L]) == "---")[1L] + 1L
    # Insert id just after opening ---
    lines <- c(lines[1L], paste0("id: ", id), lines[2L:length(lines)])
  }

  writeLines(lines, filepath)
}
