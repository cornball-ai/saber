# Tests for blast.R

library(basalt)

# --- Setup: create a fake project with functions ---

proj <- tempfile("proj")
dir.create(file.path(proj, "R"), recursive = TRUE)

writeLines(c(
  "helper <- function(x) x + 1",
  "",
  "main_fn <- function(x) {",
  "  helper(x)",
  "}"
), file.path(proj, "R", "code.R"))

writeLines("export(main_fn)", file.path(proj, "NAMESPACE"))

cache <- tempfile("symcache")

# --- blast_radius for an internal function ---

br <- blast_radius("helper", project = proj, cache_dir = cache)
expect_true(is.data.frame(br))
expect_true(nrow(br) >= 1L)
expect_true("main_fn" %in% br$caller)

# --- blast_radius for a non-existent function ---

br2 <- blast_radius("nonexistent_fn_xyz", project = proj, cache_dir = cache)
expect_equal(nrow(br2), 0L)

# --- Cleanup ---
unlink(c(proj, cache), recursive = TRUE)
