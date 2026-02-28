#' @title Startup: discover project metadata and build unified ontology
#' @description Scan home directory for CLAUDE.md, AGENT.md, and fyi.md files,
#'   build a unified ontology index, and install Claude Code instructions.

#' Build a unified ontology from project metadata files
#'
#' Scans for CLAUDE.md, AGENT.md, and fyi.md files across project directories,
#' copies them into a staging vault, indexes them, and writes usage instructions
#' to \code{~/.cache/claude/CLAUDE.md}.
#'
#' @param scan_dir Directory to scan for projects (default: home directory).
#' @param db_dir Directory for the unified ontology database and staging vault
#'   (default: \code{~/.cache/basalt}).
#' @param claude_dir Directory for Claude Code instructions file
#'   (default: \code{~/.cache/claude}).
#' @return An \code{ont_status} object (invisibly).
#' @export
ont_startup <- function(scan_dir = path.expand("~"),
                        db_dir = file.path(path.expand("~"), ".cache", "basalt"),
                        claude_dir = file.path(path.expand("~"), ".cache", "claude")) {
  scan_dir <- normalizePath(scan_dir, mustWork = TRUE)
  vault_dir <- file.path(db_dir, "vault")
  dir.create(vault_dir, recursive = TRUE, showWarnings = FALSE)

  # Discover metadata files one level deep
  targets <- c("CLAUDE.md", "AGENT.md", "fyi.md")
  project_dirs <- list.dirs(scan_dir, recursive = FALSE, full.names = TRUE)

  found <- character(0L)
  for (d in project_dirs) {
    for (t in targets) {
      fp <- file.path(d, t)
      if (file.exists(fp)) found <- c(found, fp)
    }
  }

  if (length(found) == 0L) {
    message("No CLAUDE.md, AGENT.md, or fyi.md files found in ", scan_dir)
    return(invisible(NULL))
  }

  message(sprintf("Found %d metadata file(s) across %d project(s)",
                  length(found), length(unique(dirname(found)))))

  # Copy into staging vault with project-prefixed names to avoid collisions
  # e.g. ~/cornball/CLAUDE.md -> vault/cornball--CLAUDE.md
  old_files <- list.files(vault_dir, pattern = "\\.md$", full.names = TRUE)
  if (length(old_files) > 0L) file.remove(old_files)

  for (fp in found) {
    project <- basename(dirname(fp))
    filename <- basename(fp)
    dest <- file.path(vault_dir, paste0(project, "--", filename))
    file.copy(fp, dest, overwrite = TRUE)
  }

  # Index the staging vault
  ont_index(vault_dir)

  # Write Claude Code instructions
  write_claude_instructions(claude_dir, db_dir)

  message("Ontology indexed. Instructions written to ",
          file.path(claude_dir, "CLAUDE.md"))

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

  instructions <- c(
    "# basalt: Project Ontology",
    "",
    "A unified ontology index built from CLAUDE.md, AGENT.md, and fyi.md files",
    "across all projects. Use basalt to query relationships between projects,",
    "packages, tools, and concepts.",
    "",
    "## Quick reference",
    "",
    "```r",
    "library(basalt)",
    "",
    "# Check what's indexed",
    "ont_status(db_path = \"~/.cache/basalt/vault/.ontolite/index.db\")",
    "",
    "# Query relationships",
    sprintf("ont_query(\"term\", \"is_a\", \"ancestors\", db_path = \"%s\")", db_path),
    sprintf("ont_query(\"term\", \"uses\", \"descendants\", db_path = \"%s\")", db_path),
    "",
    "# Rebuild the index after project changes",
    "ont_startup()",
    "```",
    "",
    "## Shell usage",
    "",
    "```bash",
    "# Query from the command line",
    sprintf("r -e 'basalt::ont_query(\"term\", \"is_a\", \"ancestors\", db_path = \"%s\")'", db_path),
    "",
    "# Rebuild the unified index",
    "r -e 'basalt::ont_startup()'",
    "",
    "# Check index status",
    sprintf("r -e 'basalt::ont_status(db_path = \"%s\")'", db_path),
    "```",
    "",
    "## The suggest/confirm loop",
    "",
    "basalt can propose typed relations from untyped wikilinks:",
    "",
    "```r",
    sprintf("ont_suggest(\"%s\")", file.path(db_dir, "vault")),
    "```",
    "",
    "Suggestions are written to the database with `confirmed = FALSE`.",
    "Do NOT treat unconfirmed suggestions as facts. Troy reviews them.",
    "When Troy confirms a suggestion, add the typed inline field to the",
    "source markdown file and re-index.",
    "",
    "## Correction protocol",
    "",
    "When Troy corrects a relationship (e.g., \"that's not is_a, that's uses\"):",
    "",
    "1. Edit the markdown file: change the inline field",
    "2. Run `ont_index()` or `ont_startup()` to pick up the change",
    "3. Do NOT manually patch the SQLite database",
    "",
    "When Troy says a note shouldn't be a term:",
    "",
    "1. Remove `type: term` and `id:` from frontmatter if present",
    "2. Re-index. The note drops out of the ontology.",
    "",
    "## Promoting terms",
    "",
    "To assign a stable ID to a term:",
    "",
    "```r",
    sprintf("ont_promote(\"term_name\", \"%s\")", file.path(db_dir, "vault")),
    "```",
    "",
    "This writes `id: ONTO:NNNNNNN` into the file's frontmatter.",
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
