# Tests for startup.R

library(basalt)

# --- Setup: fake home directory with projects ---

fake_home <- tempfile("home")
dir.create(fake_home)

# Project 1: R package with CLAUDE.md, fyi.md, and DESCRIPTION
proj1 <- file.path(fake_home, "mypackage")
dir.create(proj1)
writeLines(c(
  "# mypackage",
  "",
  "An R package for doing things."
), file.path(proj1, "CLAUDE.md"))

writeLines(c(
  "# mypackage internals",
  "",
  "Exports: foo, bar, baz"
), file.path(proj1, "fyi.md"))

writeLines(c(
  "Package: mypackage",
  "Version: 0.1.0",
  "Title: My Package",
  "Imports: RSQLite, yaml",
  "Suggests: tinytest"
), file.path(proj1, "DESCRIPTION"))

# Project 2: has CLAUDE.md and DESCRIPTION
proj2 <- file.path(fake_home, "otherapp")
dir.create(proj2)
writeLines(c(
  "# otherapp",
  "",
  "A downstream app."
), file.path(proj2, "CLAUDE.md"))

writeLines(c(
  "Package: otherapp",
  "Version: 0.1.0",
  "Title: Other App",
  "Imports: mypackage, jsonlite"
), file.path(proj2, "DESCRIPTION"))

# Project 3: has CLAUDE.md
proj3 <- file.path(fake_home, "agentproject")
dir.create(proj3)
writeLines(c(
  "# agentproject",
  "An agent project."
), file.path(proj3, "CLAUDE.md"))

# Project 4: AGENT.md only (no DESCRIPTION)
proj4 <- file.path(fake_home, "simpleproject")
dir.create(proj4)
writeLines(c(
  "# simpleproject",
  "A non-R project."
), file.path(proj4, "AGENT.md"))

# Project 5: README.md only
proj5 <- file.path(fake_home, "readmeonly")
dir.create(proj5)
writeLines(c(
  "# readmeonly",
  "",
  "A project with just a README."
), file.path(proj5, "README.md"))

# Directory with no metadata (should be skipped)
dir.create(file.path(fake_home, "nofiles"))

# Fake Claude Code memory directory
fake_claude <- file.path(fake_home, ".claude", "projects",
                         "-home-fakeuser-mypackage", "memory")
dir.create(fake_claude, recursive = TRUE)
writeLines(c(
  "# Memory for mypackage",
  "",
  "Key insight: uses RSQLite for everything."
), file.path(fake_claude, "MEMORY.md"))

# --- Test ont_startup ---

cache_dir <- tempfile("cache")
claude_dir <- file.path(cache_dir, "claude")

st <- ont_startup(scan_dir = fake_home,
                  db_dir = file.path(cache_dir, "basalt"),
                  claude_dir = claude_dir,
                  memory_dir = file.path(fake_home, ".claude", "projects"))

# Status should be returned
expect_true(inherits(st, "ont_status"))

# Database should exist
db <- file.path(cache_dir, "basalt", "vault", ".ontolite", "index.db")
expect_true(file.exists(db))

# --- Auto-term registration ---
con <- RSQLite::dbConnect(RSQLite::SQLite(), db)

terms <- RSQLite::dbGetQuery(con, "SELECT id, name FROM terms ORDER BY name")

# All 5 projects should be terms
expect_true("mypackage" %in% terms$name)
expect_true("otherapp" %in% terms$name)
expect_true("agentproject" %in% terms$name)
expect_true("simpleproject" %in% terms$name)
expect_true("readmeonly" %in% terms$name)

# --- DESCRIPTION dependency relations ---
rels <- RSQLite::dbGetQuery(con,
  "SELECT * FROM relations WHERE source = 'auto' ORDER BY subject_id, object_id")

# mypackage uses RSQLite and yaml
mp_deps <- rels[rels$subject_id == "mypackage", ]
expect_true("RSQLite" %in% mp_deps$object_id)
expect_true("yaml" %in% mp_deps$object_id)
expect_true(all(mp_deps$relation_type == "uses"))

# otherapp uses mypackage and jsonlite
oa_deps <- rels[rels$subject_id == "otherapp", ]
expect_true("mypackage" %in% oa_deps$object_id)
expect_true("jsonlite" %in% oa_deps$object_id)

RSQLite::dbDisconnect(con)

# --- README.md should be in vault ---
vault_files <- list.files(file.path(cache_dir, "basalt", "vault"),
                          pattern = "\\.md$")
expect_true("readmeonly--README.md" %in% vault_files)

# --- Memory files should be in vault ---
mem_files <- vault_files[grepl("^_memory--", vault_files)]
expect_true(length(mem_files) >= 1L)
expect_true(any(grepl("mypackage", mem_files)))

# --- Claude instructions ---
claude_md <- file.path(claude_dir, "CLAUDE.md")
expect_true(file.exists(claude_md))

text <- paste(readLines(claude_md), collapse = "\n")
expect_true(grepl("ont_add", text))
expect_true(grepl("ont_query", text))
expect_true(grepl("correction protocol", text, ignore.case = TRUE))

# --- Test with empty directory ---
empty_dir <- tempfile("empty")
dir.create(empty_dir)
result <- ont_startup(scan_dir = empty_dir,
                      db_dir = tempfile("emptycache"),
                      claude_dir = tempfile("emptyclaude"),
                      memory_dir = NULL)
expect_true(is.null(result))

# --- Cleanup ---
unlink(c(fake_home, cache_dir, empty_dir), recursive = TRUE)
