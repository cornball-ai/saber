# A directory alias is not a second checkout; equal package names can be.
local({
    root <- tempfile("project-aliases-")
    dir.create(root)
    on.exit(unlink(root, recursive = TRUE))
    make_package <- function(path, name, imports = "") {
        dir.create(file.path(path, "R"), recursive = TRUE)
        writeLines(c(paste("Package:", name), "Version: 1.0.0",
                     paste("Imports:", imports)), file.path(path, "DESCRIPTION"))
    }
    target <- file.path(root, "target")
    child <- file.path(root, "child")
    other <- file.path(root, "other-checkout")
    make_package(target, "target")
    make_package(child, "child", "target")
    make_package(other, "child", "target")
    writeLines("run <- function() target::helper()", file.path(child, "R", "run.R"))
    writeLines("run <- function() target::helper()", file.path(other, "R", "run.R"))
    baseline <- blast_radius("helper", target, scan_dir = root,
                             cache_dir = file.path(root, "cache"),
                             exclude = character())
    alias <- file.path(root, "aaa-alias")
    linked <- suppressWarnings(file.symlink(child, alias))
    if (isTRUE(linked)) {
        found <- projects(root, exclude = character())
        expect_equal(nrow(found), 3L)
        expect_true(child %in% found$path)
        expect_false(alias %in% found$path)
        expect_equal(sum(found$package == "child"), 2L)
        expect_equal(sort(find_downstream("target", root, character())),
                     c("child", "other-checkout"))
        calls <- blast_radius("helper", target, scan_dir = root,
                              cache_dir = file.path(root, "cache"),
                              exclude = character())
        expect_equal(calls, baseline)
        expect_equal(sort(unique(calls$project)), c("child", "other-checkout"))
        expect_equal(nrow(projects(root, exclude = "child")), 3L)
    } else {
        expect_equal(nrow(projects(root)), 3L)
    }
})
