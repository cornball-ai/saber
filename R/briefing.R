#' @title Project briefing
#' @description Generate a concise project context briefing combining ontology,
#'   memory, todos, and recent git activity.

#' Generate a project briefing
#'
#' Produces a concise markdown briefing for a project by combining ontology
#' relations, Claude Code memory files, current todo items, and recent git
#' commits. The briefing is written to \code{~/.cache/basalt/briefs/} so both
#' Claude and Troy can see the same context.
#'
#' @param project Project name. If NULL, inferred from the current working
#'   directory basename.
#' @param vault_path Path to the basalt vault.
#' @param briefs_dir Directory to write briefing markdown files.
#' @param memory_base Base directory for Claude Code project memory files.
#' @param scan_dir Directory to look for the project's git repo.
#' @param max_memory_lines Maximum lines to include from the memory file.
#' @return The briefing text (character string), returned invisibly. Also
#'   written to \code{briefs_dir/{project}.md}.
#' @export
ont_briefing <- function(project = NULL,
                         vault_path = file.path(path.expand("~"),
                                                ".cache", "basalt", "vault"),
                         briefs_dir = file.path(path.expand("~"),
                                                ".cache", "basalt", "briefs"),
                         memory_base = file.path(path.expand("~"),
                                                 ".claude", "projects"),
                         scan_dir = path.expand("~"),
                         max_memory_lines = 30L) {
  if (is.null(project)) project <- basename(getwd())
  dir.create(briefs_dir, recursive = TRUE, showWarnings = FALSE)

  lines <- character(0L)
  lines <- c(lines, sprintf("# Briefing: %s", project))
  lines <- c(lines, sprintf("_Generated %s_", format(Sys.time(),
                                                       "%Y-%m-%d %H:%M")))
  lines <- c(lines, "")

  # --- Ontology section ---
  ont <- briefing_ontology(project, vault_path)
  if (length(ont) > 0L) lines <- c(lines, ont, "")

  # --- Siblings ---
  sibs <- briefing_siblings(project, vault_path)
  if (length(sibs) > 0L) lines <- c(lines, sibs, "")

  # --- Memory ---
  mem <- briefing_memory(project, memory_base, max_memory_lines)
  if (length(mem) > 0L) lines <- c(lines, mem, "")

  # --- Recent git activity ---
  git <- briefing_git(project, scan_dir)
  if (length(git) > 0L) lines <- c(lines, git, "")

  text <- paste(lines, collapse = "\n")

  # Write to briefs dir
  outfile <- file.path(briefs_dir, paste0(project, ".md"))
  writeLines(lines, outfile)

  invisible(text)
}

#' Ontology identity section
#' @noRd
briefing_ontology <- function(project, vault_path) {
  db <- tryCatch(resolve_db(NULL, vault_path), error = function(e) NULL)
  if (is.null(db) || !file.exists(db)) return(character(0L))

  con <- tryCatch(db_connect(db), error = function(e) NULL)
  if (is.null(con)) return(character(0L))
  on.exit(RSQLite::dbDisconnect(con))

  term_id <- resolve_term(con, project)
  if (is.na(term_id)) return(sprintf("_%s is not in the ontology._", project))

  lines <- "## Identity"

  # is_a
  isa <- RSQLite::dbGetQuery(con,
    "SELECT object_id FROM relations
     WHERE subject_id = ? AND relation_type = 'is_a' AND confirmed = 1",
    params = list(term_id))
  if (nrow(isa) > 0L) {
    lines <- c(lines, sprintf("- **is_a**: %s",
                              paste(isa$object_id, collapse = ", ")))
  }

  # part_of
  partof <- RSQLite::dbGetQuery(con,
    "SELECT object_id FROM relations
     WHERE subject_id = ? AND relation_type = 'part_of' AND confirmed = 1",
    params = list(term_id))
  if (nrow(partof) > 0L) {
    lines <- c(lines, sprintf("- **part_of**: %s",
                              paste(partof$object_id, collapse = ", ")))
  }

  # wraps
  wraps <- RSQLite::dbGetQuery(con,
    "SELECT object_id FROM relations
     WHERE subject_id = ? AND relation_type = 'wraps' AND confirmed = 1",
    params = list(term_id))
  if (nrow(wraps) > 0L) {
    lines <- c(lines, sprintf("- **wraps**: %s",
                              paste(wraps$object_id, collapse = ", ")))
  }

  # direct uses (not transitive)
  uses <- RSQLite::dbGetQuery(con,
    "SELECT object_id FROM relations
     WHERE subject_id = ? AND relation_type = 'uses' AND confirmed = 1",
    params = list(term_id))
  if (nrow(uses) > 0L) {
    deps <- uses$object_id
    if (length(deps) > 15L) {
      deps <- c(deps[1:15], sprintf("... +%d more", length(deps) - 15L))
    }
    lines <- c(lines, sprintf("- **uses**: %s", paste(deps, collapse = ", ")))
  }

  lines
}

#' Siblings section
#' @noRd
briefing_siblings <- function(project, vault_path) {
  db <- tryCatch(resolve_db(NULL, vault_path), error = function(e) NULL)
  if (is.null(db) || !file.exists(db)) return(character(0L))

  con <- tryCatch(db_connect(db), error = function(e) NULL)
  if (is.null(con)) return(character(0L))
  on.exit(RSQLite::dbDisconnect(con))

  term_id <- resolve_term(con, project)
  if (is.na(term_id)) return(character(0L))

  sibs <- tryCatch(find_siblings(con, term_id, "is_a"),
                   error = function(e) NULL)
  if (is.null(sibs) || nrow(sibs) == 0L) return(character(0L))

  # Group by parent category
  parents <- unique(sibs$parent)
  lines <- "## Siblings"
  for (p in parents) {
    these <- sibs$id[sibs$parent == p]
    if (length(these) > 10L) {
      these <- c(these[1:10], sprintf("... +%d more", length(these) - 10L))
    }
    lines <- c(lines, sprintf("- **%s**: %s", p, paste(these, collapse = ", ")))
  }
  lines
}

#' Memory section
#' @noRd
briefing_memory <- function(project, memory_base, max_lines) {
  if (is.null(memory_base) || !dir.exists(memory_base)) return(character(0L))

  # Find memory dir matching this project
  mem_dirs <- list.dirs(memory_base, recursive = FALSE, full.names = TRUE)
  mem_file <- NULL
  for (md in mem_dirs) {
    proj_encoded <- basename(md)
    proj_name <- sub("^.*-home-[^-]+-", "", proj_encoded)
    if (proj_name == project) {
      candidate <- file.path(md, "memory", "MEMORY.md")
      if (file.exists(candidate)) {
        mem_file <- candidate
        break
      }
    }
  }

  if (is.null(mem_file)) return(character(0L))

  mem_lines <- readLines(mem_file, warn = FALSE)
  lines <- "## Memory"
  if (length(mem_lines) > max_lines) {
    lines <- c(lines, mem_lines[seq_len(max_lines)],
               sprintf("_... truncated (%d more lines)_",
                       length(mem_lines) - max_lines))
  } else {
    lines <- c(lines, mem_lines)
  }
  lines
}

#' Recent git activity section
#' @noRd
briefing_git <- function(project, scan_dir) {
  repo_dir <- file.path(scan_dir, project)
  if (!dir.exists(file.path(repo_dir, ".git"))) return(character(0L))

  log <- tryCatch(
    system2("git", c("-C", repo_dir, "log", "--oneline", "-5"),
            stdout = TRUE, stderr = FALSE),
    error = function(e) character(0L)
  )
  if (length(log) == 0L) return(character(0L))

  lines <- "## Recent commits"
  for (l in log) {
    lines <- c(lines, sprintf("- %s", l))
  }
  lines
}
