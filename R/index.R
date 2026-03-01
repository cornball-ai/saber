#' @title Build or update the ontology index
#' @description Parse markdown files from a vault and populate the SQLite index.

#' Build or update the ontology index from a markdown vault
#'
#' Parses all markdown files in the vault, extracts frontmatter and typed
#' links, and writes them to the SQLite index. Performs incremental updates
#' based on file hashes.
#'
#' @param vault_path Path to the markdown vault directory.
#' @return The database path (invisibly).
#' @export
index_vault <- function(vault_path) {
  vault_path <- normalizePath(vault_path, mustWork = TRUE)
  dbfile <- db_path(vault_path)
  con <- db_connect(dbfile, create = TRUE)
  on.exit(RSQLite::dbDisconnect(con))
  db_init(con)

  md_files <- list.files(vault_path, pattern = "\\.md$", recursive = TRUE,
                         full.names = TRUE)
  # Exclude files in .ontolite directory
  md_files <- md_files[!grepl("^\\.ontolite", basename(dirname(md_files)))]

  # Check which files changed
  existing <- RSQLite::dbGetQuery(con, "SELECT filepath, hash FROM files")
  rel_files <- make_relative(md_files, vault_path)

  for (i in seq_along(md_files)) {
    fp <- md_files[i]
    rel <- rel_files[i]
    h <- file_hash(fp)
    prev <- existing$hash[existing$filepath == rel]
    if (length(prev) == 1L && prev == h) next
    index_one_file(con, fp, rel, h)
  }

  # Remove entries for deleted files
  gone <- setdiff(existing$filepath, rel_files)
  if (length(gone) > 0L) {
    placeholders <- paste(rep("?", length(gone)), collapse = ", ")
    RSQLite::dbExecute(con, sprintf("DELETE FROM terms WHERE filepath IN (%s)",
                                    placeholders), params = as.list(gone))
    RSQLite::dbExecute(con, sprintf("DELETE FROM files WHERE filepath IN (%s)",
                                    placeholders), params = as.list(gone))
  }

  # Ensure typed-link targets exist as terms (even without their own file)
  ensure_link_targets(con)

  invisible(dbfile)
}

#' Index a single markdown file
#' @noRd
index_one_file <- function(con, filepath, rel_path, hash) {
  fm <- parse_frontmatter(filepath)
  links <- parse_typed_links(filepath)
  name <- name_from_path(filepath)

  # Determine if this is a term
  is_term <- !is.null(fm[["id"]]) ||
    identical(fm[["type"]], "term") ||
    nrow(links) > 0L

  if (is_term) {
    term_id <- if (!is.null(fm[["id"]])) fm[["id"]] else name
    aliases <- if (!is.null(fm[["aliases"]])) {
      paste0("[", paste(sprintf('"%s"', fm[["aliases"]]), collapse = ", "), "]")
    } else {
      "[]"
    }
    promoted <- as.integer(!is.null(fm[["id"]]))

    RSQLite::dbExecute(con,
      "INSERT INTO terms (id, name, filepath, aliases, promoted, updated_at)
       VALUES (?, ?, ?, ?, ?, strftime('%Y-%m-%dT%H:%M:%S', 'now'))
       ON CONFLICT(id) DO UPDATE SET
         name = excluded.name,
         filepath = excluded.filepath,
         aliases = excluded.aliases,
         promoted = excluded.promoted,
         updated_at = excluded.updated_at",
      params = list(term_id, name, rel_path, aliases, promoted))

    # Remove old relations from this subject and re-insert
    RSQLite::dbExecute(con,
      "DELETE FROM relations WHERE subject_id = ? AND source = 'inline'",
      params = list(term_id))

    if (nrow(links) > 0L) {
      for (j in seq_len(nrow(links))) {
        RSQLite::dbExecute(con,
          "INSERT OR IGNORE INTO relations
             (subject_id, relation_type, object_id, confirmed, source)
           VALUES (?, ?, ?, 1, 'inline')",
          params = list(term_id, links$relation_type[j], links$target[j]))
      }
    }
  }

  # Update file tracking
  RSQLite::dbExecute(con,
    "INSERT INTO files (filepath, hash, parsed_at)
     VALUES (?, ?, strftime('%Y-%m-%dT%H:%M:%S', 'now'))
     ON CONFLICT(filepath) DO UPDATE SET
       hash = excluded.hash,
       parsed_at = excluded.parsed_at",
    params = list(rel_path, hash))
}

#' Resolve relation object_ids to actual term IDs where possible,
#' then ensure remaining targets exist as stub terms.
#' @noRd
ensure_link_targets <- function(con) {
  # Resolve object_ids that match a term name to the term's actual id
  RSQLite::dbExecute(con,
    "UPDATE relations SET object_id = (
       SELECT t.id FROM terms t WHERE t.name = relations.object_id
     )
     WHERE object_id NOT IN (SELECT id FROM terms)
       AND object_id IN (SELECT name FROM terms)")

  # Create stub terms for targets that still don't exist
  RSQLite::dbExecute(con,
    "INSERT OR IGNORE INTO terms (id, name, promoted)
     SELECT DISTINCT object_id, object_id, 0
     FROM relations
     WHERE object_id NOT IN (SELECT id FROM terms)")
}

#' Make paths relative to a base directory
#' @noRd
make_relative <- function(paths, base) {
  base <- paste0(normalizePath(base, mustWork = TRUE), .Platform$file.sep)
  sub(base, "", paths, fixed = TRUE)
}
