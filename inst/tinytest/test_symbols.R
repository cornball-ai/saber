# Tests for symbols.R

library(basalt)

# --- symbols on basalt itself ---

cache <- tempfile("symcache")
syms <- symbols(system.file(package = "basalt"), cache_dir = cache)

# Should return a list with defs and calls
expect_true(is.list(syms))
expect_true("defs" %in% names(syms))
expect_true("calls" %in% names(syms))
expect_true(is.data.frame(syms$defs))
expect_true(is.data.frame(syms$calls))

# --- symbols on a temp project ---

proj <- tempfile("proj")
dir.create(file.path(proj, "R"), recursive = TRUE)

writeLines(c(
  "my_add <- function(x, y) {",
  "  x + y",
  "}",
  "",
  "my_mul <- function(x, y) {",
  "  result <- my_add(x, 0)",
  "  x * y",
  "}"
), file.path(proj, "R", "math.R"))

writeLines("export(my_add)", file.path(proj, "NAMESPACE"))

syms2 <- symbols(proj, cache_dir = cache)

# Defs
expect_true(nrow(syms2$defs) >= 2L)
expect_true("my_add" %in% syms2$defs$name)
expect_true("my_mul" %in% syms2$defs$name)

# my_add should be exported (it's in NAMESPACE)
add_row <- syms2$defs[syms2$defs$name == "my_add", ]
expect_true(add_row$exported)

# my_mul should not be exported
mul_row <- syms2$defs[syms2$defs$name == "my_mul", ]
expect_false(mul_row$exported)

# Calls: my_mul calls my_add
add_calls <- syms2$calls[syms2$calls$callee == "my_add", ]
expect_true(nrow(add_calls) >= 1L)

# --- Cache works ---

# Second call should use cache (same hashes)
syms3 <- symbols(proj, cache_dir = cache)
expect_equal(syms3$defs$name, syms2$defs$name)

# --- Empty project ---

empty_proj <- tempfile("emptyproj")
dir.create(empty_proj)
empty_syms <- symbols(empty_proj, cache_dir = cache)
expect_equal(nrow(empty_syms$defs), 0L)
expect_equal(nrow(empty_syms$calls), 0L)

# --- Cleanup ---
unlink(c(cache, proj, empty_proj), recursive = TRUE)
