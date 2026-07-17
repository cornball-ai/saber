# src_symbols() parses C/C++ via the optional bonsaisitter runtime and the
# treesitter.cpp grammar; everything below the empty-project checks is
# skipped when either is missing (e.g. during R CMD check).

# A project without src/ returns empty indices without needing tree-sitter
d_empty <- file.path(tempdir(), "nosrcpkg")
dir.create(file.path(d_empty, "R"), recursive = TRUE, showWarnings = FALSE)
idx_empty <- src_symbols(d_empty, cache_dir = tempdir())
expect_identical(nrow(idx_empty$defs), 0L)
expect_identical(nrow(idx_empty$calls), 0L)
expect_identical(names(idx_empty$defs), c("name", "file", "line", "exported"))
expect_identical(names(idx_empty$calls), c("caller", "callee", "file", "line"))

has_ts <- requireNamespace("bonsaisitter", quietly = TRUE) &&
    requireNamespace("treesitter.cpp", quietly = TRUE)

if (has_ts) {
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

    writeLines(c(
        "#include <Rinternals.h>",
        "#include <R_ext/Rdynload.h>",
        "",
        "extern SEXP c_square(SEXP);",
        "",
        "static const R_CallMethodDef CallEntries[] = {",
        "    {\"c_square\", (DL_FUNC) &c_square, 1},",
        "    {NULL, NULL, 0}",
        "};",
        "",
        "void R_init_srcpkg(DllInfo *dll) {",
        "    R_registerRoutines(dll, NULL, CallEntries, NULL, NULL);",
        "    R_useDynamicSymbols(dll, FALSE);",
        "}"
    ), file.path(d, "src", "init.c"))

    idx <- src_symbols(d, cache_dir = tempdir())

    # Definitions found with 1-based lines
    expect_true(all(c("square", "c_square", "R_init_srcpkg") %in% idx$defs$name))
    expect_identical(idx$defs$line[idx$defs$name == "square"], 3L)
    expect_identical(idx$defs$file[idx$defs$name == "square"], "square.c")

    # exported = registered in R_CallMethodDef, resolved across files
    expect_true(idx$defs$exported[idx$defs$name == "c_square"])
    expect_false(idx$defs$exported[idx$defs$name == "square"])
    expect_false(idx$defs$exported[idx$defs$name == "R_init_srcpkg"])

    # Call graph: c_square calls square; caller attribution works
    expect_true(any(idx$calls$caller == "c_square" & idx$calls$callee == "square"))

    # Cache round-trip returns identical result
    idx2 <- src_symbols(d, cache_dir = tempdir())
    expect_identical(idx, idx2)

    # blast_radius include = "src" reports the C caller
    br <- blast_radius("square", project = d, include = "src",
                       scan_dir = tempdir(), cache_dir = tempdir())
    expect_true(any(br$caller == "c_square" & br$source == "src"))
    expect_true(all(br$source == "src"))
}

# include = "src" is accepted by blast_radius validation regardless
expect_error(blast_radius("x", project = d_empty, include = "bogus",
                          scan_dir = tempdir(), cache_dir = tempdir()),
             pattern = "invalid")
