# Tests for blast.R

library(saber)

# --- Setup: create a fake project with functions ---

fake_home <- tempfile("home")
proj <- file.path(fake_home, "mypkg")
dir.create(file.path(proj, "R"), recursive = TRUE)

writeLines(c(
  "helper <- function(x) x + 1",
  "",
  "main_fn <- function(x) {",
  "  helper(x)",
  "}"
), file.path(proj, "R", "code.R"))

writeLines("export(main_fn)", file.path(proj, "NAMESPACE"))

# Create a downstream project that imports mypkg
downstream <- file.path(fake_home, "downstream")
dir.create(file.path(downstream, "R"), recursive = TRUE)

writeLines(c(
  "Package: downstream",
  "Version: 0.1.0",
  "Title: Downstream",
  "Imports: mypkg"
), file.path(downstream, "DESCRIPTION"))

writeLines(c(
  "use_helper <- function() {",
  "  mypkg::helper(42)",
  "}"
), file.path(downstream, "R", "code.R"))

cache <- tempfile("symcache")

# --- blast_radius for an internal function ---

br <- blast_radius("helper", project = proj, scan_dir = fake_home,
                   cache_dir = cache)
expect_true(is.data.frame(br))
expect_true(nrow(br) >= 1L)
expect_true("main_fn" %in% br$caller)

# --- blast_radius finds downstream callers ---

# The downstream project imports mypkg and calls mypkg::helper
expect_true(any(br$project == "downstream"))

# --- blast_radius for a non-existent function ---

br2 <- blast_radius("nonexistent_fn_xyz", project = proj,
                    scan_dir = fake_home, cache_dir = cache)
expect_equal(nrow(br2), 0L)

# --- Cleanup ---
unlink(c(fake_home, cache), recursive = TRUE)
