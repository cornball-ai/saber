# src_symbols() parses C/C++/Python via the optional bonsaisitter runtime
# and per-language grammar packages; language-specific blocks are skipped
# when the runtime or a grammar is missing (e.g. during R CMD check).

# A project with no matching sources returns empty indices without
# needing tree-sitter at all
d_empty <- file.path(tempdir(), "nosrcpkg")
dir.create(file.path(d_empty, "R"), recursive = TRUE, showWarnings = FALSE)
idx_empty <- src_symbols(d_empty, cache_dir = tempdir())
expect_identical(nrow(idx_empty$defs), 0L)
expect_identical(nrow(idx_empty$calls), 0L)
expect_identical(names(idx_empty$defs),
                 c("name", "file", "line", "lang", "exported"))
expect_identical(names(idx_empty$calls),
                 c("caller", "callee", "file", "line", "lang"))

# Invalid langs error regardless of tree-sitter availability
expect_error(src_symbols(d_empty, langs = "fortran", cache_dir = tempdir()),
             pattern = "invalid")

has_bonsai <- requireNamespace("bonsaisitter", quietly = TRUE)
has_cpp <- has_bonsai &&
    (requireNamespace("treesitter.c", quietly = TRUE) ||
     requireNamespace("treesitter.cpp", quietly = TRUE))
has_py <- has_bonsai && requireNamespace("treesitter.python", quietly = TRUE)
has_rust <- has_bonsai && requireNamespace("treesitter.rust", quietly = TRUE)
has_js <- has_bonsai &&
    requireNamespace("treesitter.javascript", quietly = TRUE)

if (has_cpp) {
    d <- file.path(tempdir(), "srcpkg")
    dir.create(file.path(d, "R"), recursive = TRUE, showWarnings = FALSE)
    dir.create(file.path(d, "src"), recursive = TRUE, showWarnings = FALSE)

    writeLines(c(
        "#include <Rinternals.h>",
        "",
        "static double square(double x) {",
        "    return x * x;",
        "}",
        "",
        "SEXP c_square(SEXP x) {",
        "    return Rf_ScalarReal(square(Rf_asReal(x)));",
        "}"
    ), file.path(d, "src", "square.c"))

    idx <- src_symbols(d, cache_dir = tempdir())

    # Definitions found with project-relative paths and 1-based lines
    expect_true(all(c("square", "c_square") %in% idx$defs$name))
    expect_identical(idx$defs$line[idx$defs$name == "square"], 3L)
    expect_identical(idx$defs$file[idx$defs$name == "square"], "src/square.c")
    expect_identical(unique(idx$defs$lang), "c")

    # exported = external linkage: static square is file-local
    expect_true(idx$defs$exported[idx$defs$name == "c_square"])
    expect_false(idx$defs$exported[idx$defs$name == "square"])

    # Call graph: c_square calls square; caller attribution works
    expect_true(any(idx$calls$caller == "c_square" & idx$calls$callee == "square"))

    # Cache round-trip returns identical result
    idx2 <- src_symbols(d, cache_dir = tempdir())
    expect_identical(idx, idx2)

    # Excluded directories are skipped at any depth
    dir.create(file.path(d, "src", "vendor"), showWarnings = FALSE)
    writeLines("int vendored(void) { return 1; }",
               file.path(d, "src", "vendor", "dep.c"))
    idx3 <- src_symbols(d, cache_dir = tempdir())
    expect_true("vendored" %in% idx3$defs$name)
    idx4 <- src_symbols(d, exclude = c(default_src_exclude(), "vendor"),
                        cache_dir = tempdir())
    expect_false("vendored" %in% idx4$defs$name)

    # default_src_exclude() carries the default_exclude() opt-outs, so
    # user directories like Documents are skipped by default
    expect_true(all(default_exclude() %in% default_src_exclude()))
    dir.create(file.path(d, "Documents"), showWarnings = FALSE)
    writeLines("int personal(void) { return 1; }",
               file.path(d, "Documents", "note.c"))
    idx5 <- src_symbols(d, cache_dir = tempdir())
    expect_false("personal" %in% idx5$defs$name)

    # *.Rcheck directories are always skipped, even with exclude = NULL
    dir.create(file.path(d, "srcpkg.Rcheck"), showWarnings = FALSE)
    writeLines("int checked(void) { return 1; }",
               file.path(d, "srcpkg.Rcheck", "chk.c"))
    idx6 <- src_symbols(d, exclude = NULL, cache_dir = tempdir())
    expect_false("checked" %in% idx6$defs$name)
    expect_true("personal" %in% idx6$defs$name)
    unlink(file.path(d, "Documents"), recursive = TRUE)
    unlink(file.path(d, "srcpkg.Rcheck"), recursive = TRUE)

    # blast_radius include = "src" reports the C caller
    unlink(file.path(d, "src", "vendor"), recursive = TRUE)
    br <- blast_radius("square", project = d, include = "src",
                       scan_dir = tempdir(), cache_dir = tempdir())
    expect_true(any(br$caller == "c_square" & br$source == "src"))
    expect_true(all(br$source == "src"))
}

if (has_py) {
    dp <- file.path(tempdir(), "pypkg")
    dir.create(dp, recursive = TRUE, showWarnings = FALSE)

    writeLines(c(
        "def _helper(x):",
        "    return x + 1",
        "",
        "def compute(x):",
        "    return _helper(x) * 2",
        "",
        "class Model:",
        "    def forward(self, x):",
        "        return self.decode(compute(x))"
    ), file.path(dp, "model.py"))

    pidx <- src_symbols(dp, cache_dir = tempdir())

    # Functions, classes, and methods all indexed
    expect_true(all(c("_helper", "compute", "Model", "forward") %in% pidx$defs$name))
    expect_identical(unique(pidx$defs$lang), "python")

    # exported = no leading underscore
    expect_false(pidx$defs$exported[pidx$defs$name == "_helper"])
    expect_true(pidx$defs$exported[pidx$defs$name == "compute"])

    # Caller attribution: compute calls _helper, forward calls compute
    expect_true(any(pidx$calls$caller == "compute" & pidx$calls$callee == "_helper"))
    expect_true(any(pidx$calls$caller == "forward" & pidx$calls$callee == "compute"))

    # Attribute callees keep their receiver
    expect_true(any(pidx$calls$callee == "self.decode"))
}

if (has_rust) {
    dr <- file.path(tempdir(), "rustpkg")
    dir.create(file.path(dr, "src"), recursive = TRUE, showWarnings = FALSE)

    writeLines(c(
        "pub struct Point { x: f64 }",
        "",
        "fn helper(x: f64) -> f64 {",
        "    x.abs()",
        "}",
        "",
        "pub fn compute(x: f64) -> f64 {",
        "    helper(x) * 2.0",
        "}"
    ), file.path(dr, "src", "lib.rs"))

    ridx <- src_symbols(dr, cache_dir = tempdir())

    # Functions and structs indexed
    expect_true(all(c("Point", "helper", "compute") %in% ridx$defs$name))
    expect_identical(unique(ridx$defs$lang), "rust")

    # exported = declared pub
    expect_true(ridx$defs$exported[ridx$defs$name == "compute"])
    expect_true(ridx$defs$exported[ridx$defs$name == "Point"])
    expect_false(ridx$defs$exported[ridx$defs$name == "helper"])

    # Caller attribution: compute calls helper
    expect_true(any(ridx$calls$caller == "compute" & ridx$calls$callee == "helper"))

    # Cargo target/ is excluded by default
    dir.create(file.path(dr, "target"), showWarnings = FALSE)
    writeLines("pub fn generated() {}", file.path(dr, "target", "gen.rs"))
    ridx2 <- src_symbols(dr, cache_dir = tempdir())
    expect_false("generated" %in% ridx2$defs$name)
}

if (has_js) {
    dj <- file.path(tempdir(), "jspkg")
    dir.create(dj, recursive = TRUE, showWarnings = FALSE)

    writeLines(c(
        "function helper(x) {",
        "    return x + 1;",
        "}",
        "",
        "export function compute(x) {",
        "    return helper(x) * 2;",
        "}",
        "",
        "const dbl = (x) => compute(x) + compute(x);",
        "",
        "class Model {",
        "    forward(x) { return this.decode(compute(x)); }",
        "}"
    ), file.path(dj, "app.js"))

    jidx <- src_symbols(dj, cache_dir = tempdir())

    # Declarations, arrow-function consts, classes, and methods indexed
    expect_true(all(c("helper", "compute", "dbl", "Model", "forward") %in%
        jidx$defs$name))
    expect_identical(unique(jidx$defs$lang), "javascript")

    # exported = wrapped in an export statement
    expect_true(jidx$defs$exported[jidx$defs$name == "compute"])
    expect_false(jidx$defs$exported[jidx$defs$name == "helper"])

    # Caller attribution across def kinds
    expect_true(any(jidx$calls$caller == "compute" & jidx$calls$callee == "helper"))
    expect_true(any(jidx$calls$caller == "dbl" & jidx$calls$callee == "compute"))
    expect_true(any(jidx$calls$caller == "forward" & jidx$calls$callee == "this.decode"))
}

# include = "src" is accepted by blast_radius validation regardless
expect_error(blast_radius("x", project = d_empty, include = "bogus",
                          scan_dir = tempdir(), cache_dir = tempdir()),
             pattern = "invalid")
