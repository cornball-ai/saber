# Tests for startup.R

library(basalt)

# --- Setup: fake home directory with projects ---

fake_home <- tempfile("home")
dir.create(fake_home)

# Project 1: has CLAUDE.md and fyi.md
proj1 <- file.path(fake_home, "mypackage")
dir.create(proj1)
writeLines(c(
  "---",
  "type: term",
  "---",
  "# mypackage",
  "",
  "An R package for doing things.",
  "uses:: [[RSQLite]]"
), file.path(proj1, "CLAUDE.md"))

writeLines(c(
  "---",
  "type: term",
  "---",
  "# mypackage internals",
  "",
  "Exports: foo, bar, baz"
), file.path(proj1, "fyi.md"))

# Project 2: has CLAUDE.md only
proj2 <- file.path(fake_home, "otherapp")
dir.create(proj2)
writeLines(c(
  "---",
  "type: term",
  "---",
  "# otherapp",
  "",
  "is_a:: [[mypackage]]",
  "A downstream app."
), file.path(proj2, "CLAUDE.md"))

# Project 3: has AGENT.md
proj3 <- file.path(fake_home, "agentproject")
dir.create(proj3)
writeLines(c(
  "---",
  "type: term",
  "---",
  "# agentproject",
  "",
  "uses:: [[otherapp]]"
), file.path(proj3, "AGENT.md"))

# Directory with no metadata (should be skipped)
dir.create(file.path(fake_home, "nofiles"))

# --- Test ont_startup ---

cache_dir <- tempfile("cache")
claude_dir <- file.path(cache_dir, "claude")

st <- ont_startup(scan_dir = fake_home,
                  db_dir = file.path(cache_dir, "basalt"),
                  claude_dir = claude_dir)

# Status should be returned
expect_true(inherits(st, "ont_status"))
expect_true(st$terms >= 3L)

# Database should exist
db <- file.path(cache_dir, "basalt", "vault", ".ontolite", "index.db")
expect_true(file.exists(db))

# Vault staging directory should have prefixed copies
vault_files <- list.files(file.path(cache_dir, "basalt", "vault"),
                          pattern = "\\.md$")
expect_true("mypackage--CLAUDE.md" %in% vault_files)
expect_true("mypackage--fyi.md" %in% vault_files)
expect_true("otherapp--CLAUDE.md" %in% vault_files)
expect_true("agentproject--AGENT.md" %in% vault_files)

# Claude instructions should be written
claude_md <- file.path(claude_dir, "CLAUDE.md")
expect_true(file.exists(claude_md))

# Instructions should contain key sections
instructions <- readLines(claude_md)
text <- paste(instructions, collapse = "\n")
expect_true(grepl("basalt", text))
expect_true(grepl("ont_query", text))
expect_true(grepl("ont_startup", text))
expect_true(grepl("suggest", text, ignore.case = TRUE))
expect_true(grepl("correction protocol", text, ignore.case = TRUE))
expect_true(grepl("ont_promote", text))

# --- Test with empty directory ---
empty_dir <- tempfile("empty")
dir.create(empty_dir)
result <- ont_startup(scan_dir = empty_dir, db_dir = tempfile("emptycache"))
expect_true(is.null(result))

# --- Cleanup ---
unlink(c(fake_home, cache_dir, empty_dir), recursive = TRUE)
