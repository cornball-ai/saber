# Tests for index.R

library(basalt)

# Create a temp vault
vault <- tempfile("vault")
dir.create(vault)

# Write some test files
writeLines(c(
  "---",
  "id: ONTO:0000001",
  "type: term",
  "aliases:",
  "  - ML",
  "---",
  "# Machine Learning",
  "A field of study."
), file.path(vault, "Machine Learning.md"))

writeLines(c(
  "---",
  "type: term",
  "---",
  "# Neural Networks",
  "is_a:: [[Machine Learning]]",
  "Some content about NNs."
), file.path(vault, "Neural Networks.md"))

writeLines(c(
  "# Just a note",
  "This is not a term.",
  "It links to [[Machine Learning]] though."
), file.path(vault, "Random Note.md"))

# --- index_vault ---

dbfile <- index_vault(vault)
expect_true(file.exists(dbfile))

con <- RSQLite::dbConnect(RSQLite::SQLite(), dbfile)

# Check terms were created
terms <- RSQLite::dbGetQuery(con, "SELECT * FROM terms ORDER BY name")
expect_true(nrow(terms) >= 2L)
expect_true("Machine Learning" %in% terms$name)
expect_true("Neural Networks" %in% terms$name)

# ML should be promoted (has id:)
ml <- terms[terms$name == "Machine Learning", ]
expect_equal(ml$promoted, 1L)
expect_equal(ml$id, "ONTO:0000001")

# NN should not be promoted
nn <- terms[terms$name == "Neural Networks", ]
expect_equal(nn$promoted, 0L)

# Check relations
rels <- RSQLite::dbGetQuery(con, "SELECT * FROM relations")
expect_true(nrow(rels) >= 1L)
isa <- rels[rels$relation_type == "is_a", ]
expect_true(nrow(isa) >= 1L)

# Check files tracking
files <- RSQLite::dbGetQuery(con, "SELECT * FROM files")
expect_true(nrow(files) >= 2L)

RSQLite::dbDisconnect(con)

# --- Incremental re-index (no changes) ---
dbfile2 <- index_vault(vault)
expect_equal(dbfile, dbfile2)

# --- Re-index after change ---
writeLines(c(
  "---",
  "type: term",
  "---",
  "# Deep Learning",
  "is_a:: [[Neural Networks]]"
), file.path(vault, "Deep Learning.md"))

index_vault(vault)
con <- RSQLite::dbConnect(RSQLite::SQLite(), dbfile)
terms2 <- RSQLite::dbGetQuery(con, "SELECT * FROM terms ORDER BY name")
expect_true("Deep Learning" %in% terms2$name)
RSQLite::dbDisconnect(con)

unlink(vault, recursive = TRUE)
