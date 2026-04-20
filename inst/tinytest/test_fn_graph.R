# Tests for fn_graph.R

library(saber)

d <- file.path(tempdir(), paste0("fngraph-", format(Sys.time(), "%H%M%S")))
dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
writeLines(c("Package: demo", "Version: 0.1.0"), file.path(d, "DESCRIPTION"))
writeLines("add <- function(x, y) x + y", file.path(d, "R", "add.R"))
writeLines("double <- function(x) add(x, x)", file.path(d, "R", "double.R"))

svg <- fn_graph(d)
expect_true(is.character(svg))
expect_true(any(grepl("^<svg", svg)))
# Tooltips carry name + file:line + visibility + degree
expect_true(any(grepl("add.R:1", svg, fixed = TRUE)))
expect_true(any(grepl("double.R:1", svg, fixed = TRUE)))
expect_true(any(grepl("called by 1", svg, fixed = TRUE)))
expect_true(any(grepl("calls 1", svg, fixed = TRUE)))
expect_equal(sum(grepl("<line ", svg)), 1L)
