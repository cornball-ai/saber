#' @title Startup: discover project metadata and build unified ontology
#' @description Scan home directory for project metadata, auto-register
#'   projects as terms, infer relations from DESCRIPTION files, and install
#'   Claude Code instructions.

#' Build a unified ontology from project metadata files
#'
#' Scans for CLAUDE.md, AGENT.md, fyi.md, README.md, and DESCRIPTION files
#' across project directories. Also discovers Claude Code memory files from
#' \code{~/.claude/projects/*/memory/*.md}. Every project with recognized
#' metadata becomes a term automatically. R package dependencies from
#' DESCRIPTION files generate \code{uses} relations. Central annotation
#' files from \code{~/.cache/basalt/annotations/} are included in the index.
#'
#' @param scan_dir Directory to scan for projects (default: home directory).
#' @param db_dir Directory for the unified ontology database and staging vault
#'   (default: \code{~/.cache/basalt}).
#' @param claude_dir Directory for Claude Code instructions file
#'   (default: \code{~/.cache/claude}).
#' @param memory_dir Directory containing Claude Code project memory files
#'   (default: \code{~/.claude/projects}). Set to NULL to skip.
#' @return An \code{ont_status} object (invisibly).
#' @export
ont_startup <- function(scan_dir = path.expand("~"),
                        db_dir = file.path(path.expand("~"), ".cache", "basalt"),
                        claude_dir = file.path(path.expand("~"), ".cache", "claude"),
                        memory_dir = file.path(path.expand("~"), ".claude", "projects")) {
  scan_dir <- normalizePath(scan_dir, mustWork = TRUE)
  vault_dir <- file.path(db_dir, "vault")
  annotations_dir <- file.path(db_dir, "annotations")
  dir.create(vault_dir, recursive = TRUE, showWarnings = FALSE)

  # Discover project directories
  project_dirs <- list.dirs(scan_dir, recursive = FALSE, full.names = TRUE)

  # Which files to look for
  md_targets <- c("CLAUDE.md", "AGENT.md", "fyi.md", "README.md")

  # Gather metadata files and identify projects
  found_md <- character(0L)
  found_desc <- character(0L)
  project_names <- character(0L)

  for (d in project_dirs) {
    has_metadata <- FALSE
    for (t in md_targets) {
      fp <- file.path(d, t)
      if (file.exists(fp)) {
        found_md <- c(found_md, fp)
        has_metadata <- TRUE
      }
    }
    desc_fp <- file.path(d, "DESCRIPTION")
    if (file.exists(desc_fp)) {
      found_desc <- c(found_desc, desc_fp)
      has_metadata <- TRUE
    }
    if (has_metadata) {
      project_names <- c(project_names, basename(d))
    }
  }

  # Discover Claude Code memory files (~/.claude/projects/*/memory/*.md)
  found_memories <- character(0L)
  if (!is.null(memory_dir) && dir.exists(memory_dir)) {
    mem_dirs <- list.dirs(memory_dir, recursive = FALSE,
                          full.names = TRUE)
    for (md in mem_dirs) {
      mem_path <- file.path(md, "memory")
      if (dir.exists(mem_path)) {
        mfiles <- list.files(mem_path, pattern = "\\.md$", full.names = TRUE)
        if (length(mfiles) > 0L) found_memories <- c(found_memories, mfiles)
      }
    }
  }

  if (length(project_names) == 0L) {
    message("No project metadata found in ", scan_dir)
    return(invisible(NULL))
  }

  message(sprintf("Found %d project(s) (%d markdown, %d DESCRIPTION, %d memory files)",
                  length(project_names), length(found_md), length(found_desc),
                  length(found_memories)))

  # Clear old vault files
  old_files <- list.files(vault_dir, pattern = "\\.md$", full.names = TRUE)
  if (length(old_files) > 0L) file.remove(old_files)

  # Copy markdown files into staging vault
  for (fp in found_md) {
    project <- basename(dirname(fp))
    filename <- basename(fp)
    dest <- file.path(vault_dir, paste0(project, "--", filename))
    file.copy(fp, dest, overwrite = TRUE)
  }

  # Copy Claude Code memory files into vault
  # Directory names are like -home-troy-whisper -> project "whisper"
  for (fp in found_memories) {
    mem_dir <- dirname(fp)           # .../memory
    proj_dir <- dirname(mem_dir)     # .../-home-troy-whisper
    proj_encoded <- basename(proj_dir)
    # Extract project name: last segment after splitting on -home-troy-
    proj_name <- sub("^.*-home-[^-]+-", "", proj_encoded)
    filename <- basename(fp)
    dest <- file.path(vault_dir,
                      paste0("_memory--", proj_name, "--", filename))
    file.copy(fp, dest, overwrite = TRUE)
  }

  # Copy central annotation files into vault
  if (dir.exists(annotations_dir)) {
    ann_files <- list.files(annotations_dir, pattern = "\\.md$",
                            full.names = TRUE)
    for (fp in ann_files) {
      dest <- file.path(vault_dir, paste0("_annotations--", basename(fp)))
      file.copy(fp, dest, overwrite = TRUE)
    }
  }

  # Index the vault (picks up typed links from basalt.md and annotation files)
  ont_index(vault_dir)

  # Now add auto-terms and DESCRIPTION relations directly to the DB
  dbfile <- db_path(vault_dir)
  con <- db_connect(dbfile)
  on.exit(RSQLite::dbDisconnect(con))

  # Auto-register every project as a term
  for (pname in project_names) {
    RSQLite::dbExecute(con,
      "INSERT OR IGNORE INTO terms (id, name, promoted, updated_at)
       VALUES (?, ?, 0, strftime('%Y-%m-%dT%H:%M:%S', 'now'))",
      params = list(pname, pname))
  }

  # Parse DESCRIPTION files for dependency relations
  n_deps <- 0L
  for (desc_fp in found_desc) {
    info <- parse_description(desc_fp)
    if (is.na(info$package)) next
    pname <- basename(dirname(desc_fp))

    for (dep in info$imports) {
      RSQLite::dbExecute(con,
        "INSERT OR IGNORE INTO relations
           (subject_id, relation_type, object_id, confirmed, source)
         VALUES (?, 'uses', ?, 1, 'auto')",
        params = list(pname, dep))
      # Ensure the dependency exists as a term
      RSQLite::dbExecute(con,
        "INSERT OR IGNORE INTO terms (id, name, promoted, updated_at)
         VALUES (?, ?, 0, strftime('%Y-%m-%dT%H:%M:%S', 'now'))",
        params = list(dep, dep))
      n_deps <- n_deps + 1L
    }
  }

  # Resolve link targets (in case basalt.md files reference project names)
  ensure_link_targets(con)

  RSQLite::dbDisconnect(con)
  on.exit(NULL)

  # Write Claude Code instructions
  write_claude_instructions(claude_dir, db_dir)

  message(sprintf("Indexed %d project(s), %d dependency relation(s). Instructions written to %s",
                  length(project_names), n_deps, file.path(claude_dir, "CLAUDE.md")))

  invisible(ont_status(vault_path = vault_dir))
}

#' Write Claude Code usage instructions
#'
#' @param claude_dir Path to the Claude cache directory.
#' @param db_dir Path to the basalt database directory.
#' @noRd
write_claude_instructions <- function(claude_dir, db_dir) {
  dir.create(claude_dir, recursive = TRUE, showWarnings = FALSE)
  outfile <- file.path(claude_dir, "CLAUDE.md")

  db_path <- file.path(db_dir, "vault", ".ontolite", "index.db")
  vault_path <- file.path(db_dir, "vault")

  instructions <- c(
    "# basalt: Project Ontology",
    "",
    "A unified ontology index built from CLAUDE.md, AGENT.md, fyi.md, README.md,",
    "DESCRIPTION files, and Claude Code memory files across all projects.",
    "Projects are auto-registered as terms. R package dependencies are",
    "auto-inferred as `uses` relations.",
    "",
    "## Quick reference",
    "",
    "```r",
    "library(basalt)",
    "",
    "# Check what's indexed",
    sprintf("ont_status(db_path = \"%s\")", db_path),
    "",
    "# Query relationships",
    sprintf("ont_query(\"torch\", \"uses\", \"descendants\", db_path = \"%s\")", db_path),
    sprintf("ont_query(\"whisper\", \"uses\", \"ancestors\", db_path = \"%s\")", db_path),
    "",
    "# Rebuild the index after project changes",
    "ont_startup()",
    "```",
    "",
    "## Adding terms and relations",
    "",
    "LLMs and users can bootstrap the ontology programmatically:",
    "",
    "```r",
    "# Add terms",
    sprintf("ont_add(terms = c(\"transformer\", \"attention\"), vault_path = \"%s\")", vault_path),
    "",
    "# Add relations",
    "ont_add(",
    "  relations = data.frame(",
    "    subject = c(\"whisper\", \"transformer\"),",
    "    relation_type = c(\"is_a\", \"uses\"),",
    "    object = c(\"speech_to_text\", \"attention\")",
    "  ),",
    sprintf("  vault_path = \"%s\"", vault_path),
    ")",
    "```",
    "",
    "Additions are written to `~/.cache/basalt/annotations/` as markdown",
    "files so they persist across re-indexes.",
    "",
    "## Shell usage",
    "",
    "```bash",
    sprintf("r -e 'basalt::ont_query(\"torch\", \"uses\", \"descendants\", db_path = \"%s\")'", db_path),
    "r -e 'basalt::ont_startup()'",
    sprintf("r -e 'basalt::ont_status(db_path = \"%s\")'", db_path),
    "```",
    "",
    "## The suggest/confirm loop",
    "",
    "basalt can propose typed relations from untyped wikilinks:",
    "",
    "```r",
    sprintf("ont_suggest(\"%s\")", vault_path),
    "```",
    "",
    "Suggestions are written to the database with `confirmed = FALSE`.",
    "Do NOT treat unconfirmed suggestions as facts. Troy reviews them.",
    "",
    "## Correction protocol",
    "",
    "When Troy corrects a relationship (e.g., \"that's not is_a, that's uses\"):",
    "",
    "1. Edit the annotation file in ~/.cache/basalt/annotations/",
    "2. Run `ont_startup()` to pick up the change",
    "3. Do NOT manually patch the SQLite database",
    "",
    "## Promoting terms",
    "",
    "```r",
    sprintf("ont_promote(\"term_name\", \"%s\")", vault_path),
    "```",
    "",
    "Only do this when Troy asks. Never auto-promote.",
    "",
    "## OBO export",
    "",
    "```r",
    sprintf("ont_emit_obo(db_path = \"%s\", outfile = \"ontology.obo\")", db_path),
    "```"
  )

  writeLines(instructions, outfile)
}
