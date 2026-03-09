# Tests for pkg.R

library(saber)

# --- pkg_exports ---

# saber itself is a good test subject
exp <- pkg_exports("saber")
expect_true(is.data.frame(exp))
expect_true(nrow(exp) > 0L)
expect_true("name" %in% names(exp))
expect_true("args" %in% names(exp))
expect_true("symbols" %in% exp$name)
expect_true("blast_radius" %in% exp$name)

# Pattern filter
exp2 <- pkg_exports("saber", pattern = "^pkg_")
expect_true(nrow(exp2) >= 2L)
expect_true(all(grepl("^pkg_", exp2$name)))

# Non-existent package
expect_error(pkg_exports("nonexistent_pkg_12345"))

# --- pkg_internals ---

int <- pkg_internals("saber")
expect_true(is.data.frame(int))
expect_true(nrow(int) > 0L)
# file_hash is internal
expect_true("file_hash" %in% int$name)

# Pattern filter
int2 <- pkg_internals("saber", pattern = "^file_")
expect_true(nrow(int2) >= 1L)
expect_true(all(grepl("^file_", int2$name)))

# --- pkg_help ---

# Get help for a known topic
md <- pkg_help("symbols", "saber")
expect_true(is.character(md))
expect_true(nchar(md) > 0L)
expect_true(grepl("project_dir|symbol|AST", md))

# Non-existent topic
expect_error(pkg_help("nonexistent_topic_xyz", "saber"))
