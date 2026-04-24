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

# --- source column is populated with "r" for R source hits ---
expect_true("source" %in% names(br))
expect_true(all(br$source == "r"))

# --- blast_radius finds downstream callers ---

# The downstream project imports mypkg and calls mypkg::helper
expect_true(any(br$project == "downstream"))

# --- blast_radius for a non-existent function ---

br2 <- blast_radius("nonexistent_fn_xyz", project = proj,
                    scan_dir = fake_home, cache_dir = cache)
expect_equal(nrow(br2), 0L)
expect_true("source" %in% names(br2))

# --- include validation ---
expect_error(blast_radius("helper", project = proj, include = "bogus",
                          scan_dir = fake_home, cache_dir = cache))

# --- include = "examples": scans roxygen @examples blocks ---

# Add a second function whose roxygen @examples calls helper()
writeLines(c(
  "#' Documented fn",
  "#'",
  "#' @param x input",
  "#' @examples",
  "#' helper(1)",
  "#' \\dontrun{",
  "#' helper(2)",
  "#' }",
  "#' @export",
  "documented <- function(x) x",
  "",
  "#' Other fn with prose only",
  "#' @examples",
  "#' # helper is mentioned in a comment but not called",
  "#' 1 + 1",
  "#' @export",
  "other <- function(x) x"
), file.path(proj, "R", "documented.R"))

# Invalidate cache so symbols() re-reads
unlink(cache, recursive = TRUE)

br_ex <- blast_radius("helper", project = proj,
                      include = c("r", "examples"),
                      scan_dir = fake_home, cache_dir = cache)
ex_rows <- br_ex[br_ex$source == "example",, drop = FALSE]
expect_true(nrow(ex_rows) >= 2L)        # two calls inside @examples
expect_equal(unique(ex_rows$file), "documented.R")
expect_true("documented" %in% ex_rows$caller)
# The prose-only @examples block in `other` should NOT match
expect_false(any(ex_rows$caller == "other"))

# Without examples, the ex hits disappear
br_no_ex <- blast_radius("helper", project = proj, include = "r",
                         scan_dir = fake_home, cache_dir = cache)
expect_false(any(br_no_ex$source == "example"))

# --- include = "vignettes": scans Rmd code chunks ---

dir.create(file.path(proj, "vignettes"))
writeLines(c(
  "---",
  "title: demo",
  "---",
  "",
  "Some prose that mentions helper() but is not in a chunk.",
  "",
  "```{r setup}",
  "helper(10)",
  "```",
  "",
  "More prose.",
  "",
  "```{r, eval=FALSE}",
  "mypkg::helper(20)",
  "```"
), file.path(proj, "vignettes", "demo.Rmd"))

br_vi <- blast_radius("helper", project = proj,
                      include = c("r", "vignettes"),
                      scan_dir = fake_home, cache_dir = cache)
vi_rows <- br_vi[br_vi$source == "vignette",, drop = FALSE]
expect_equal(nrow(vi_rows), 2L)
expect_true(all(grepl("demo\\.Rmd$", vi_rows$file)))
# Prose mention outside chunks is not counted
expect_false(any(vi_rows$line == 5L))

# --- include accepts all three at once ---
br_all <- blast_radius("helper", project = proj,
                       include = c("r", "examples", "vignettes"),
                       scan_dir = fake_home, cache_dir = cache)
expect_true(all(c("r", "example", "vignette") %in% br_all$source))

# --- Cleanup ---
unlink(c(fake_home, cache), recursive = TRUE)
