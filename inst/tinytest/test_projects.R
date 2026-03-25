# Tests for projects() and find_downstream()

# --- Setup ---
scan_dir <- file.path(tempdir(), "test_projects")
dir.create(scan_dir, showWarnings = FALSE)

pkg_a <- file.path(scan_dir, "pkgA")
pkg_b <- file.path(scan_dir, "pkgB")
dir.create(pkg_a, showWarnings = FALSE)
dir.create(pkg_b, showWarnings = FALSE)

writeLines(c(
    "Package: pkgA",
    "Title: Package A",
    "Version: 1.0.0",
    "Imports: stats"
), file.path(pkg_a, "DESCRIPTION"))

writeLines(c(
    "Package: pkgB",
    "Title: Package B",
    "Version: 0.2.0",
    "Imports: pkgA, utils"
), file.path(pkg_b, "DESCRIPTION"))

# --- projects() ---
res <- projects(scan_dir = scan_dir)
expect_true(is.data.frame(res))
expect_equal(nrow(res), 2L)
expect_true("pkgA" %in% res$package)
expect_true("pkgB" %in% res$package)
expect_true("package" %in% names(res))
expect_true("title" %in% names(res))
expect_true("version" %in% names(res))
expect_true("path" %in% names(res))

row_a <- res[res$package == "pkgA", ]
expect_equal(row_a$title, "Package A")
expect_equal(row_a$version, "1.0.0")

# --- projects() empty dir ---
empty <- file.path(tempdir(), "test_projects_empty")
dir.create(empty, showWarnings = FALSE)
res_empty <- projects(scan_dir = empty)
expect_equal(nrow(res_empty), 0L)

# --- find_downstream() ---
ds <- find_downstream("pkgA", scan_dir = scan_dir)
expect_equal(ds, "pkgB")

ds_none <- find_downstream("pkgB", scan_dir = scan_dir)
expect_equal(length(ds_none), 0L)

ds_missing <- find_downstream("nonexistent", scan_dir = scan_dir)
expect_equal(length(ds_missing), 0L)

# --- Cleanup ---
unlink(scan_dir, recursive = TRUE)
unlink(empty, recursive = TRUE)
