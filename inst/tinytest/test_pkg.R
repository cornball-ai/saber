# Tests for pkg.R

library(basalt)

# --- pkg_exports ---

# basalt itself is a good test subject
exp <- pkg_exports("basalt")
expect_true(is.data.frame(exp))
expect_true(nrow(exp) > 0L)
expect_true("name" %in% names(exp))
expect_true("args" %in% names(exp))
expect_true("query" %in% exp$name)
expect_true("status" %in% exp$name)

# Pattern filter
exp2 <- pkg_exports("basalt", pattern = "^pkg_")
expect_true(nrow(exp2) >= 2L)
expect_true(all(grepl("^pkg_", exp2$name)))

# Non-existent package
expect_error(pkg_exports("nonexistent_pkg_12345"))

# --- pkg_internals ---

int <- pkg_internals("basalt")
expect_true(is.data.frame(int))
expect_true(nrow(int) > 0L)
# resolve_term is internal
expect_true("resolve_term" %in% int$name)

# Pattern filter
int2 <- pkg_internals("basalt", pattern = "^resolve")
expect_true(nrow(int2) >= 1L)
expect_true(all(grepl("^resolve", int2$name)))

# --- pkg_help ---

# Get help for a known topic
md <- pkg_help("query", "basalt")
expect_true(is.character(md))
expect_true(nchar(md) > 0L)
expect_true(grepl("ancestors|descendants|siblings", md))

# Non-existent topic
expect_error(pkg_help("nonexistent_topic_xyz", "basalt"))
