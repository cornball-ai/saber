# Tests for pkg_graph.R

library(saber)

d <- file.path(tempdir(), paste0("pkggraph-", format(Sys.time(), "%H%M%S")))
dir.create(d, showWarnings = FALSE)

parent_dir <- file.path(d, "parent")
child_dir <- file.path(d, "child")
dir.create(parent_dir, showWarnings = FALSE)
dir.create(child_dir, showWarnings = FALSE)
writeLines(c("Package: parent", "Title: Parent", "Version: 0.1.0"),
           file.path(parent_dir, "DESCRIPTION"))
writeLines(c("Package: child", "Title: Child", "Version: 0.1.0",
             "Imports: parent (>= 0.1.0)"),
           file.path(child_dir, "DESCRIPTION"))

svg <- pkg_graph(scan_dir = d)
# Tooltips carry title + version + dep counts
expect_true(any(grepl("parent 0.1.0", svg, fixed = TRUE)))
expect_true(any(grepl("child 0.1.0", svg, fixed = TRUE)))
expect_true(any(grepl("1 deps (1 local)", svg, fixed = TRUE)))
expect_equal(sum(grepl("<line ", svg)), 1L)

expect_equal(saber:::parse_deps("foo (>= 1.0), bar, R (>= 3.5)"),
             c("foo", "bar"))
expect_equal(saber:::parse_deps(""), character())
expect_equal(saber:::parse_deps(NA_character_), character())

svg <- pkg_graph(scan_dir = d, packages = "parent")
expect_true(any(grepl("parent 0.1.0", svg, fixed = TRUE)))
expect_false(any(grepl("child 0.1.0", svg, fixed = TRUE)))
