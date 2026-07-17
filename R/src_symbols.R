#' @title Code intelligence: C/C++ symbol index
#' @description Parse a package's src/ C and C++ sources into function
#'   definitions and call relationships via tree-sitter.

#' Build a symbol index for a project's src/ directory
#'
#' Parses top-level \code{src/} C and C++ files (\code{.c}, \code{.cc},
#' \code{.cpp}, \code{.h}, \code{.hpp}) into function definitions and call
#' relationships, mirroring the shape of \code{\link{symbols}}. Vendored
#' code in \code{src/} subdirectories is not scanned. Results are cached as
#' RDS in the user cache directory alongside the \code{symbols()} cache.
#'
#' A definition is marked \code{exported} when its name appears in an R
#' registration table (\code{R_CallMethodDef}, \code{R_CMethodDef},
#' \code{R_FortranMethodDef}, \code{R_ExternalMethodDef}), meaning it is
#' reachable from R via \code{.Call()} and friends.
#'
#' Parsing uses the suggested \pkg{bonsaisitter} tree-sitter runtime with the
#' \pkg{treesitter.cpp} grammar package; both must be installed. Projects
#' without a \code{src/} directory return empty indices without requiring
#' either package.
#'
#' @param project_dir Path to the project directory.
#' @param cache_dir Directory for symbol cache files.
#' @return A list with components:
#'   \describe{
#'     \item{defs}{data.frame(name, file, line, exported)}
#'     \item{calls}{data.frame(caller, callee, file, line)}
#'   }
#' @examples
#' if (requireNamespace("bonsaisitter", quietly = TRUE) &&
#'     requireNamespace("treesitter.cpp", quietly = TRUE)) {
#'
#'     # Create a minimal project with a src/ directory
#'     d <- file.path(tempdir(), "srcdemo")
#'     dir.create(file.path(d, "src"), recursive = TRUE, showWarnings = FALSE)
#'     writeLines(c(
#'         "static double square(double x) { return x * x; }",
#'         "double area(double r) { return 3.14159 * square(r); }"
#'     ), file.path(d, "src", "area.c"))
#'
#'     idx <- src_symbols(d, cache_dir = tempdir())
#'     idx$defs   # C function definitions
#'     idx$calls  # call relationships (area calls square)
#' }
#' @export
src_symbols <- function(project_dir,
                        cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols")) {
    project_dir <- normalizePath(project_dir, mustWork = TRUE)
    project_name <- basename(project_dir)

    empty <- list(defs = data.frame(name = character(), file = character(),
                                    line = integer(), exported = logical(),
                                    stringsAsFactors = FALSE),
                  calls = data.frame(caller = character(), callee = character(),
                                     file = character(), line = integer(),
                                     stringsAsFactors = FALSE))

    src_dir <- file.path(project_dir, "src")
    if (!dir.exists(src_dir)) {
        return(empty)
    }
    src_files <- list.files(src_dir, pattern = "\\.(c|cc|cpp|h|hpp)$",
                            full.names = TRUE)
    if (length(src_files) == 0L) {
        return(empty)
    }

    # Check cache (".src.rds" suffix keeps it apart from the symbols() cache)
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, paste0(project_name, ".src.rds"))

    hashes <- vapply(src_files, file_hash, character(1))
    hash_key <- paste(sort(paste(basename(src_files), hashes)), collapse = "|")

    if (file.exists(cache_file)) {
        cached <- readRDS(cache_file)
        if (identical(cached$hash_key, hash_key)) {
            return(cached$result)
        }
    }

    ts_parser <- cpp_parser()

    all_defs <- empty$defs
    all_defs$start_byte <- double()
    all_defs$end_byte <- double()
    all_calls <- empty$calls
    registered <- character()

    for (fp in src_files) {
        pd <- parse_src_file(ts_parser, fp)
        if (is.null(pd) || nrow(pd) == 0L) {
            next
        }
        rel_file <- basename(fp)
        file_defs <- extract_src_defs(pd, rel_file)
        all_defs <- rbind(all_defs, file_defs)
        all_calls <- rbind(all_calls, extract_src_calls(pd, rel_file, file_defs))
        registered <- c(registered, registration_names(pd))
    }

    # Registration tables usually live in init.c while the functions they
    # register are defined elsewhere, so mark exports project-wide
    all_defs$exported <- all_defs$name %in% registered
    all_defs <- all_defs[, c("name", "file", "line", "exported"), drop = FALSE]
    rownames(all_defs) <- NULL

    result <- list(defs = all_defs, calls = all_calls)

    saveRDS(list(hash_key = hash_key, result = result), cache_file)

    result
}

#' Create a tree-sitter C/C++ parser, or fail with install guidance
#' @noRd
cpp_parser <- function() {
    for (pkg in c("bonsaisitter", "treesitter.cpp")) {
        if (!requireNamespace(pkg, quietly = TRUE)) {
            stop("src_symbols() requires the '", pkg,
                 "' package to parse C/C++ sources. Install it first.",
                 call. = FALSE)
        }
    }
    lang <- getExportedValue("treesitter.cpp", "language")()
    bonsaisitter::parser(lang)
}

#' Parse one C/C++ file into a flat node data.frame
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

#' Extract function definitions from a flat C/C++ node frame
#'
#' Returns defs with start_byte/end_byte kept for caller attribution;
#' src_symbols() strips them before returning.
#' @noRd
extract_src_defs <- function(pd, file) {
    defs <- data.frame(name = character(), file = character(),
                       line = integer(), exported = logical(),
                       start_byte = double(), end_byte = double(),
                       stringsAsFactors = FALSE)

    fdefs <- pd[pd$type == "function_definition",, drop = FALSE]
    for (i in seq_len(nrow(fdefs))) {
        fd <- fdefs[i,]
        fn_name <- src_def_name(pd, fd)
        if (is.null(fn_name)) {
            next
        }
        defs <- rbind(defs,
                      data.frame(name = fn_name, file = file,
                                 line = fd$start_row + 1L, exported = FALSE,
                                 start_byte = fd$start_byte,
                                 end_byte = fd$end_byte,
                                 stringsAsFactors = FALSE))
    }

    defs
}

#' Name of a function_definition node
#'
#' The definition's own declarator is the earliest function_declarator in
#' its range; the name is the widest identifier-like node at the
#' declarator's start (widest so that C++ qualified names win over their
#' identifier parts).
#' @noRd
src_def_name <- function(pd, fd) {
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
    cand$text[which.max(cand$end_byte)]
}

#' Extract function calls from a flat C/C++ node frame
#'
#' The callee of a call_expression is the widest identifier-like node
#' sharing its start byte (e.g. "square", "obj->method", "ns::fn"). Calls
#' through unnamed expressions (function pointers) are skipped.
#' @noRd
extract_src_calls <- function(pd, file, defs) {
    calls <- data.frame(caller = character(), callee = character(),
                        file = character(), line = integer(),
                        stringsAsFactors = FALSE)

    callee_types <- c("identifier", "field_expression", "qualified_identifier",
                      "template_function")
    ces <- pd[pd$type == "call_expression",, drop = FALSE]
    for (i in seq_len(nrow(ces))) {
        ce <- ces[i,]
        cand <- pd[pd$start_byte == ce$start_byte & pd$end_byte < ce$end_byte &
            pd$type %in% callee_types,, drop = FALSE]
        if (nrow(cand) == 0L) {
            next
        }
        callee <- cand$text[which.max(cand$end_byte)]
        caller <- enclosing_src_def(ce$start_byte, defs)
        calls <- rbind(calls,
                       data.frame(caller = caller, callee = callee, file = file,
                                  line = ce$start_row + 1L,
                                  stringsAsFactors = FALSE))
    }

    calls
}

#' Find which function definition encloses a byte offset
#' @noRd
enclosing_src_def <- function(byte, defs) {
    if (nrow(defs) == 0L) {
        return("<top-level>")
    }
    inside <- defs[defs$start_byte <= byte & defs$end_byte >= byte,, drop = FALSE]
    if (nrow(inside) == 0L) {
        return("<top-level>")
    }
    # If nested, pick the innermost (smallest range)
    inside$span <- inside$end_byte - inside$start_byte
    inside$name[which.min(inside$span)]
}

#' C functions registered with R (R_CallMethodDef and friends)
#'
#' Identifiers inside a registration-table declaration are the registered
#' C functions (referenced as \code{&fn}). Table array names caught along
#' the way are harmless: exported status intersects with actual defs.
#' @noRd
registration_names <- function(pd) {
    tables <- pd[pd$type == "declaration" &
        grepl("R_(Call|C|Fortran|External)MethodDef", pd$text),, drop = FALSE]
    if (nrow(tables) == 0L) {
        return(character())
    }

    found <- character()
    for (i in seq_len(nrow(tables))) {
        tb <- tables[i,]
        ids <- pd[pd$type == "identifier" & pd$start_byte >= tb$start_byte &
            pd$end_byte <= tb$end_byte,, drop = FALSE]
        found <- c(found, ids$text)
    }

    unique(found)
}
