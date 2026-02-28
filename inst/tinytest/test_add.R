# Tests for add.R

library(basalt)

# --- Setup: create a vault with one term ---

vault <- tempfile("vault")
dir.create(vault)

writeLines(c(
  "---",
  "type: term",
  "---",
  "# Existing Term"
), file.path(vault, "Existing Term.md"))

ont_index(vault)

annotations_dir <- tempfile("annotations")

# --- Test adding terms ---

res <- ont_add(
  terms = c("alpha", "beta", "gamma"),
  vault_path = vault,
  annotations_dir = annotations_dir
)

expect_equal(res$terms, 3L)
expect_equal(res$relations, 0L)

# Verify in DB
con <- RSQLite::dbConnect(RSQLite::SQLite(),
  file.path(vault, ".ontolite", "index.db"))
terms <- RSQLite::dbGetQuery(con, "SELECT id FROM terms ORDER BY id")
expect_true("alpha" %in% terms$id)
expect_true("beta" %in% terms$id)
expect_true("gamma" %in% terms$id)

# --- Test adding relations ---

rels_df <- data.frame(
  subject = c("alpha", "beta"),
  relation_type = c("is_a", "uses"),
  object = c("gamma", "alpha"),
  stringsAsFactors = FALSE
)

res2 <- ont_add(
  relations = rels_df,
  vault_path = vault,
  annotations_dir = annotations_dir
)

expect_equal(res2$relations, 2L)

rels <- RSQLite::dbGetQuery(con, "SELECT * FROM relations WHERE source = 'manual'")
expect_equal(nrow(rels), 2L)
expect_true(all(rels$confirmed == 1L))

# alpha is_a gamma
expect_true(any(rels$subject_id == "alpha" & rels$relation_type == "is_a" &
                rels$object_id == "gamma"))
# beta uses alpha
expect_true(any(rels$subject_id == "beta" & rels$relation_type == "uses" &
                rels$object_id == "alpha"))

RSQLite::dbDisconnect(con)

# --- Test annotation file written ---

ann_files <- list.files(annotations_dir, pattern = "\\.md$")
expect_true(length(ann_files) >= 1L)

# --- Test duplicate inserts are ignored ---

res3 <- ont_add(
  terms = c("alpha", "new_term"),
  relations = rels_df,
  vault_path = vault,
  annotations_dir = annotations_dir
)

# alpha already exists, only new_term is new
expect_equal(res3$terms, 1L)
# relations already exist
expect_equal(res3$relations, 0L)

# --- Test bad relations input ---

expect_error(
  ont_add(relations = data.frame(a = 1, b = 2), vault_path = vault,
          annotations_dir = NULL),
  "subject, relation_type, object"
)

# --- Cleanup ---
unlink(c(vault, annotations_dir), recursive = TRUE)
