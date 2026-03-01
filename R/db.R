#' @title Database helpers
#' @description Schema init and connection management for the ontology index.

#' Get the default database path for a vault
#'
#' @param vault_path Path to the markdown vault.
#' @return Path to the SQLite database file.
#' @noRd
db_path <- function(vault_path) {
  file.path(vault_path, ".ontolite", "index.db")
}

#' Open a connection to the ontology database
#'
#' @param path Path to the SQLite database file.
#' @param create If TRUE, create the database and schema if missing.
#' @return A DBIconnection object.
#' @noRd
db_connect <- function(path, create = FALSE) {
  if (!create && !file.exists(path)) {
    stop("Database not found: ", path, ". Run index_vault() first.")
  }
  if (create) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
  }
  con <- RSQLite::dbConnect(RSQLite::SQLite(), path)
  RSQLite::dbExecute(con, "PRAGMA foreign_keys = ON")
  RSQLite::dbExecute(con, "PRAGMA journal_mode = WAL")
  con
}

#' Initialize the database schema
#'
#' @param con A DBIconnection object.
#' @noRd
db_init <- function(con) {
  schema_file <- system.file("sql", "schema.sql", package = "basalt")
  if (schema_file == "") {
    stop("Cannot find schema.sql. Is basalt installed?")
  }
  sql <- readLines(schema_file, warn = FALSE)
  sql <- paste(sql, collapse = "\n")
  statements <- strsplit(sql, ";")[[1L]]
  statements <- trimws(statements)
  statements <- statements[nchar(statements) > 0L]
  for (stmt in statements) {
    RSQLite::dbExecute(con, stmt)
  }
  invisible(con)
}
