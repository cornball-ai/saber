#' @title Code intelligence: multi-language symbol index
#' @description Parse C, C++, Python, Rust, and JavaScript sources into
#'   function definitions and call relationships via tree-sitter.

#' Build a symbol index for a project's non-R sources
#'
#' Recursively scans \code{project_dir} for C (\code{.c}, \code{.h}), C++
#' (\code{.cc}, \code{.cpp}, \code{.cxx}, \code{.hh}, \code{.hpp}), Python
#' (\code{.py}), Rust (\code{.rs}), and JavaScript (\code{.js},
#' \code{.mjs}, \code{.cjs}, \code{.jsx}) sources and parses them into
#' function definitions and call relationships, mirroring the shape of
#' \code{\link{symbols}} with an added \code{lang} column. This covers the
#' \code{src/} directory of an R package as well as repositories that are
#' not R packages at all. Directories named in \code{exclude} are skipped,
#' as are hidden directories and \code{*.Rcheck} directories, always.
#' Results are cached as RDS in the user cache directory alongside the
#' \code{symbols()} cache.
#'
#' A definition is marked \code{exported} when it is visible beyond its own
#' file or module: for C/C++, definitions not declared \code{static}; for
#' Python, names without a leading underscore; for Rust, items declared
#' \code{pub}; for JavaScript, definitions wrapped in an \code{export}
#' statement.
#'
#' Parsing uses the suggested \pkg{bonsaisitter} tree-sitter runtime with
#' one grammar package per language: \pkg{treesitter.c} for C (falling back
#' to \pkg{treesitter.cpp}, which also parses C), \pkg{treesitter.cpp} for
#' C++, \pkg{treesitter.python} for Python, \pkg{treesitter.rust} for Rust,
#' and \pkg{treesitter.javascript} for JavaScript. Grammars are only
#' required for languages that actually match files, and projects with no
#' matching files return empty indices without requiring any of them.
#'
#' @param project_dir Path to the project directory.
#' @param langs Character vector of languages to index. Any of \code{"c"},
#'   \code{"cpp"}, \code{"python"}, \code{"rust"}, \code{"javascript"}
#'   (all five by default).
#' @param exclude Character vector of directory basenames to skip while
#'   scanning, e.g. vendored or generated trees. The default
#'   \code{\link{default_src_exclude}} includes the
#'   \code{\link{default_exclude}} opt-outs, so user directories such as
#'   \code{Documents} stay untouched even when scanning from a home
#'   directory.
#' @param cache_dir Directory for symbol cache files.
#' @return A list with components:
#'   \describe{
#'     \item{defs}{data.frame(name, file, line, lang, exported)}
#'     \item{calls}{data.frame(caller, callee, file, line, lang)}
#'   }
#' @examples
#' # Needs the bonsaisitter runtime; also needs a grammar package per
#' # language, tolerated via tryCatch() so the example survives its absence
#' if (requireNamespace("bonsaisitter", quietly = TRUE)) {
#'
#'     # Create a minimal project with a src/ directory
#'     d <- file.path(tempdir(), "srcdemo")
#'     dir.create(file.path(d, "src"), recursive = TRUE, showWarnings = FALSE)
#'     writeLines(c(
#'         "static double square(double x) { return x * x; }",
#'         "double area(double r) { return 3.14159 * square(r); }"
#'     ), file.path(d, "src", "area.c"))
#'
#'     idx <- tryCatch(src_symbols(d, cache_dir = tempdir()),
#'                     error = function(e) NULL)
#'     idx$defs   # C function definitions
#'     idx$calls  # call relationships (area calls square)
#' }
#' @export
src_symbols <- function(project_dir,
                        langs = c("c", "cpp", "python", "rust", "javascript"),
                        exclude = default_src_exclude(),
                        cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols")) {
    project_dir <- normalizePath(project_dir, mustWork = TRUE)
    project_name <- basename(project_dir)

    bad <- setdiff(langs, names(src_extensions()))
    if (length(bad) > 0L) {
        stop("invalid 'langs' value(s): ", paste(bad, collapse = ", "),
             ". Allowed: ", paste(names(src_extensions()), collapse = ", "))
    }

    empty <- list(defs = data.frame(name = character(), file = character(),
                                    line = integer(), lang = character(),
                                    exported = logical(),
                                    stringsAsFactors = FALSE),
                  calls = data.frame(caller = character(), callee = character(),
                                     file = character(), line = integer(),
                                     lang = character(),
                                     stringsAsFactors = FALSE))

    src_files <- find_src_files(project_dir, langs, exclude)
    if (nrow(src_files) == 0L) {
        return(empty)
    }

    # Check cache (".src.rds" suffix keeps it apart from the symbols() cache;
    # the file set already reflects langs and exclude)
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, paste0(project_name, ".src.rds"))

    paths <- file.path(project_dir, src_files$file)
    hashes <- vapply(paths, file_hash, character(1))
    hash_key <- paste(sort(paste(src_files$file, hashes)), collapse = "|")

    if (file.exists(cache_file)) {
        cached <- readRDS(cache_file)
        if (identical(cached$hash_key, hash_key)) {
            return(cached$result)
        }
    }

    parsers <- list()
    defs_acc <- list(rbind_def_rows(list()))
    calls_acc <- list(empty$calls)

    for (i in seq_len(nrow(src_files))) {
        lang <- src_files$lang[i]
        if (is.null(parsers[[lang]])) {
            parsers[[lang]] <- src_parser(lang)
        }
        pd <- parse_src_file(parsers[[lang]], file.path(project_dir, src_files$file[i]))
        if (is.null(pd) || nrow(pd) == 0L) {
            next
        }
        rel_file <- src_files$file[i]
        file_defs <- switch(lang,
                            python = extract_py_defs(pd, rel_file),
                            rust = extract_rust_defs(pd, rel_file),
                            javascript = extract_js_defs(pd, rel_file),
                            extract_c_defs(pd, rel_file, lang))
        spec <- src_call_spec(lang)
        file_calls <- extract_src_calls(pd, rel_file, file_defs,
                                        call_type = spec$type,
                                        callee_types = spec$callees,
                                        lang = lang)
        defs_acc[[length(defs_acc) + 1L]] <- file_defs
        calls_acc[[length(calls_acc) + 1L]] <- file_calls
    }

    all_defs <- do.call(rbind, defs_acc)
    all_defs <- all_defs[, c("name", "file", "line", "lang", "exported"), drop = FALSE]
    rownames(all_defs) <- NULL

    result <- list(defs = all_defs, calls = do.call(rbind, calls_acc))

    saveRDS(list(hash_key = hash_key, result = result), cache_file)

    result
}

#' Default directories to exclude when scanning for source files
#'
#' Returns a character vector of directory basenames that
#' \code{\link{src_symbols}} skips while scanning: everything in
#' \code{\link{default_exclude}} (user directories such as
#' \code{Documents}, plus caches and build artifacts), extended with
#' dependency and build trees whose sources are not the project's own
#' (including cargo's \code{target}).
#' Hidden directories (e.g. \code{.git}) and \code{*.Rcheck} directories
#' are always skipped, whatever the \code{exclude} value. Extend it for
#' vendored code, e.g. \code{c(default_src_exclude(), "tree-sitter")}.
#'
#' @return Character vector of directory basenames.
#' @examples
#' default_src_exclude()
#' @export
default_src_exclude <- function() {
    unique(c(default_exclude(), "__pycache__", "venv", "build", "dist",
             "renv", "target"))
}

#' File extensions per supported language
#' @noRd
src_extensions <- function() {
    list(c = c("c", "h"), cpp = c("cc", "cpp", "cxx", "hh", "hpp"),
         python = "py", rust = "rs",
         javascript = c("js", "mjs", "cjs", "jsx"))
}

#' Call node type and callee node types per language
#'
#' The callee types are the named nodes that can carry a call's name:
#' plain identifiers plus each language's member/path access form.
#' @noRd
src_call_spec <- function(lang) {
    switch(lang,
           python = list(type = "call", callees = c("identifier", "attribute")),
           rust = list(type = "call_expression",
                       callees = c("identifier", "field_expression", "scoped_identifier")),
           javascript = list(type = "call_expression",
                             callees = c("identifier", "member_expression")),
           list(type = "call_expression",
                callees = c("identifier", "field_expression",
                            "qualified_identifier", "template_function")))
}

#' Find source files under a project, tagged with their language
#'
#' Returns a data.frame(file, lang) of project-relative paths. Hidden
#' directories are skipped by list.files(); excluded directory basenames
#' and *.Rcheck directories are dropped from any depth of the relative
#' path.
#' @noRd
find_src_files <- function(project_dir, langs, exclude) {
    exts <- unlist(src_extensions()[langs], use.names = FALSE)
    pattern <- paste0("\\.(", paste(exts, collapse = "|"), ")$")
    rel <- list.files(project_dir, pattern = pattern, recursive = TRUE)

    if (length(rel) > 0L) {
        parts <- strsplit(dirname(rel), "/", fixed = TRUE)
        dropped <- vapply(parts, function(p) {
            any(p %in% exclude | endsWith(p, ".Rcheck"))
        }, logical(1))
        rel <- rel[!dropped]
    }

    ext <- tolower(sub(".*\\.", "", rel))
    lang_by_ext <- rep(names(src_extensions()), lengths(src_extensions()))
    names(lang_by_ext) <- unlist(src_extensions(), use.names = FALSE)

    data.frame(file = rel, lang = unname(lang_by_ext[ext]),
               stringsAsFactors = FALSE)
}

#' Create a tree-sitter parser for a language, or fail with install guidance
#'
#' C prefers the treesitter.c grammar and falls back to treesitter.cpp,
#' which parses C with the same node types.
#' @noRd
src_parser <- function(lang) {
    if (!requireNamespace("bonsaisitter", quietly = TRUE)) {
        stop("src_symbols() requires the 'bonsaisitter' package. ",
             "Install it first.", call. = FALSE)
    }
    grammar_pkgs <- switch(lang,
                           c = c("treesitter.c", "treesitter.cpp"),
                           cpp = "treesitter.cpp",
                           python = "treesitter.python",
                           rust = "treesitter.rust",
                           javascript = "treesitter.javascript")
    for (pkg in grammar_pkgs) {
        if (requireNamespace(pkg, quietly = TRUE)) {
            grammar <- getExportedValue(pkg, "language")()
            return(bonsaisitter::parser(grammar))
        }
    }
    stop("src_symbols() requires the '", grammar_pkgs[length(grammar_pkgs)],
         "' package to parse ", lang, " sources. Install it first.",
         call. = FALSE)
}

#' Parse one source file into a flat node data.frame
#' @noRd
parse_src_file <- function(ts_parser, filepath) {
    text <- paste(readLines(filepath, warn = FALSE), collapse = "\n")
    tree <- tryCatch(bonsaisitter::parser_parse(ts_parser, text),
                     error = function(e) NULL)
    if (is.null(tree)) {
        return(NULL)
    }
    as.data.frame(bonsaisitter::tree_root_node(tree))
}

#' Extract C/C++ function definitions from a flat node frame
#'
#' Keeps start_byte/end_byte for caller attribution; src_symbols() strips
#' them before returning. exported = not declared static.
#' @noRd
extract_c_defs <- function(pd, file, lang) {
    fdefs <- pd[pd$type == "function_definition",, drop = FALSE]
    rows <- vector("list", nrow(fdefs))
    for (i in seq_len(nrow(fdefs))) {
        fd <- fdefs[i,]
        info <- c_def_info(pd, fd)
        if (is.null(info)) {
            next
        }
        rows[[i]] <- data.frame(name = info$name, file = file,
                                line = fd$start_row + 1L, lang = lang,
                                exported = info$exported,
                                start_byte = fd$start_byte,
                                end_byte = fd$end_byte,
                                stringsAsFactors = FALSE)
    }
    rbind_def_rows(rows)
}

#' Name and linkage of a C/C++ function_definition node
#'
#' The definition's own declarator is the earliest function_declarator in
#' its range; the name is the widest identifier-like node at the
#' declarator's start (widest so that C++ qualified names win over their
#' identifier parts). A "static" storage class before the declarator makes
#' the definition file-local.
#' @noRd
c_def_info <- function(pd, fd) {
    inside <- pd$start_byte >= fd$start_byte & pd$end_byte <= fd$end_byte
    decls <- pd[inside & pd$type == "function_declarator",, drop = FALSE]
    if (nrow(decls) == 0L) {
        return(NULL)
    }
    decl <- decls[which.min(decls$start_byte),]

    name_types <- c("identifier", "field_identifier", "qualified_identifier",
                    "operator_name", "destructor_name")
    cand <- pd[pd$start_byte == decl$start_byte & pd$end_byte < decl$end_byte &
        pd$type %in% name_types,, drop = FALSE]
    if (nrow(cand) == 0L) {
        return(NULL)
    }

    is_static <- any(pd$type == "storage_class_specifier" &
                     pd$text == "static" & pd$start_byte >= fd$start_byte &
                     pd$start_byte < decl$start_byte)

    list(name = cand$text[which.max(cand$end_byte)], exported = !is_static)
}

#' Extract Python function and class definitions from a flat node frame
#'
#' The name is the first identifier inside the definition: it directly
#' follows the "def"/"class" keyword, before parameters, bases, or body.
#' exported = no leading underscore.
#' @noRd
extract_py_defs <- function(pd, file) {
    fdefs <- pd[pd$type %in% c("function_definition", "class_definition"),,
        drop = FALSE]
    rows <- vector("list", nrow(fdefs))
    for (i in seq_len(nrow(fdefs))) {
        fd <- fdefs[i,]
        ids <- pd[pd$type == "identifier" & pd$start_byte >= fd$start_byte &
            pd$end_byte <= fd$end_byte,, drop = FALSE]
        if (nrow(ids) == 0L) {
            next
        }
        fn_name <- ids$text[which.min(ids$start_byte)]
        rows[[i]] <- data.frame(name = fn_name, file = file,
                                line = fd$start_row + 1L, lang = "python",
                                exported = !startsWith(fn_name, "_"),
                                start_byte = fd$start_byte,
                                end_byte = fd$end_byte,
                                stringsAsFactors = FALSE)
    }
    rbind_def_rows(rows)
}

#' Extract Rust item definitions from a flat node frame
#'
#' Indexes functions, structs, enums, and traits. The name is the first
#' identifier-like node inside the item: it directly follows the item
#' keyword, before generics, parameters, or body. exported = declared
#' with a visibility modifier (pub), which starts the item when present.
#' @noRd
extract_rust_defs <- function(pd, file) {
    def_types <- c("function_item", "struct_item", "enum_item", "trait_item")
    fdefs <- pd[pd$type %in% def_types,, drop = FALSE]
    rows <- vector("list", nrow(fdefs))
    for (i in seq_len(nrow(fdefs))) {
        fd <- fdefs[i,]
        ids <- pd[pd$type %in% c("identifier", "type_identifier") &
            pd$start_byte >= fd$start_byte & pd$end_byte <= fd$end_byte,,
            drop = FALSE]
        if (nrow(ids) == 0L) {
            next
        }
        is_pub <- any(pd$type == "visibility_modifier" &
                      pd$start_byte == fd$start_byte)
        rows[[i]] <- data.frame(name = ids$text[which.min(ids$start_byte)],
                                file = file, line = fd$start_row + 1L,
                                lang = "rust", exported = is_pub,
                                start_byte = fd$start_byte,
                                end_byte = fd$end_byte,
                                stringsAsFactors = FALSE)
    }
    rbind_def_rows(rows)
}

#' Extract JavaScript definitions from a flat node frame
#'
#' Indexes function and class declarations, methods, and variables bound
#' to arrow functions or function expressions (the value node ends where
#' the declarator ends). The name is the first identifier-like node inside
#' the definition. exported = wrapped in an ES module export statement;
#' CommonJS module.exports assignments are not detected.
#' @noRd
extract_js_defs <- function(pd, file) {
    def_types <- c("function_declaration", "generator_function_declaration",
                   "class_declaration", "method_definition")
    fdefs <- pd[pd$type %in% def_types,, drop = FALSE]

    vds <- pd[pd$type == "variable_declarator",, drop = FALSE]
    fn_vals <- pd[pd$type %in% c("arrow_function", "function_expression"),,
        drop = FALSE]
    if (nrow(vds) > 0L && nrow(fn_vals) > 0L) {
        fn_valued <- vapply(seq_len(nrow(vds)), function(i) {
            any(fn_vals$start_byte > vds$start_byte[i] &
                fn_vals$end_byte == vds$end_byte[i])
        }, logical(1))
        fdefs <- rbind(fdefs, vds[fn_valued,, drop = FALSE])
    }

    exports <- pd[pd$type == "export_statement",, drop = FALSE]

    rows <- vector("list", nrow(fdefs))
    for (i in seq_len(nrow(fdefs))) {
        fd <- fdefs[i,]
        ids <- pd[pd$type %in% c("identifier", "property_identifier") &
            pd$start_byte >= fd$start_byte & pd$end_byte <= fd$end_byte,,
            drop = FALSE]
        if (nrow(ids) == 0L) {
            next
        }
        is_exported <- any(exports$start_byte <= fd$start_byte &
                           exports$end_byte >= fd$end_byte)
        rows[[i]] <- data.frame(name = ids$text[which.min(ids$start_byte)],
                                file = file, line = fd$start_row + 1L,
                                lang = "javascript", exported = is_exported,
                                start_byte = fd$start_byte,
                                end_byte = fd$end_byte,
                                stringsAsFactors = FALSE)
    }
    rbind_def_rows(rows)
}

#' Combine per-definition rows, or an empty defs frame
#' @noRd
rbind_def_rows <- function(rows) {
    rows <- Filter(Negate(is.null), rows)
    if (length(rows) == 0L) {
        return(data.frame(name = character(), file = character(),
                          line = integer(), lang = character(),
                          exported = logical(), start_byte = double(),
                          end_byte = double(), stringsAsFactors = FALSE))
    }
    do.call(rbind, rows)
}

#' Extract function calls from a flat node frame
#'
#' The callee of a call node is the widest callee-typed node sharing its
#' start byte (e.g. "square", "obj->method", "self.helper", "ns::fn").
#' Calls through unnamed expressions (function pointers, lambdas) are
#' skipped.
#' @noRd
extract_src_calls <- function(pd, file, defs, call_type, callee_types, lang) {
    ces <- pd[pd$type == call_type,, drop = FALSE]
    rows <- vector("list", nrow(ces))
    for (i in seq_len(nrow(ces))) {
        ce <- ces[i,]
        cand <- pd[pd$start_byte == ce$start_byte & pd$end_byte < ce$end_byte &
            pd$type %in% callee_types,, drop = FALSE]
        if (nrow(cand) == 0L) {
            next
        }
        rows[[i]] <- data.frame(caller = enclosing_src_def(ce$start_byte, defs),
                                callee = cand$text[which.max(cand$end_byte)],
                                file = file, line = ce$start_row + 1L,
                                lang = lang, stringsAsFactors = FALSE)
    }
    rows <- Filter(Negate(is.null), rows)
    if (length(rows) == 0L) {
        return(data.frame(caller = character(), callee = character(),
                          file = character(), line = integer(),
                          lang = character(), stringsAsFactors = FALSE))
    }
    do.call(rbind, rows)
}

#' Find which definition encloses a byte offset
#' @noRd
enclosing_src_def <- function(byte, defs) {
    if (nrow(defs) == 0L) {
        return("<top-level>")
    }
    inside <- defs[defs$start_byte <= byte &
        defs$end_byte >= byte,, drop = FALSE]
    if (nrow(inside) == 0L) {
        return("<top-level>")
    }
    # If nested, pick the innermost (smallest range)
    inside$span <- inside$end_byte - inside$start_byte
    inside$name[which.min(inside$span)]
}
