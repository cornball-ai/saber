#' @title AST symbol index
#' @description Parse R source files to extract function definitions and calls.

#' Build a symbol index for a project
#'
#' Parses all \code{R/*.R} files in a project directory using
#' \code{getParseData()} to extract function definitions and function calls.
#' Results are cached as RDS in \code{~/.cache/R/saber/symbols/}.
#'
#' @param project_dir Path to the project directory.
#' @param cache_dir Directory for symbol cache files.
#' @return A list with components:
#'   \describe{
#'     \item{defs}{data.frame(name, file, line, exported)}
#'     \item{calls}{data.frame(caller, callee, file, line)}
#'   }
#' @export
symbols <- function(project_dir,
                    cache_dir = file.path(tools::R_user_dir("saber", "cache"), "symbols")) {
    project_dir <- normalizePath(project_dir, mustWork = TRUE)
    project_name <- basename(project_dir)

    r_dir <- file.path(project_dir, "R")
    if (!dir.exists(r_dir)) {
        return(list(defs = data.frame(name = character(), file = character(),
                                      line = integer(), exported = logical(),
                                      stringsAsFactors = FALSE),
                    calls = data.frame(caller = character(), callee = character(),
                                       file = character(), line = integer(),
                                       stringsAsFactors = FALSE)))
    }

    r_files <- list.files(r_dir, pattern = "\\.[Rr]$", full.names = TRUE)
    if (length(r_files) == 0L) {
        return(list(defs = data.frame(name = character(), file = character(),
                                      line = integer(), exported = logical(),
                                      stringsAsFactors = FALSE),
                    calls = data.frame(caller = character(), callee = character(),
                                       file = character(), line = integer(),
                                       stringsAsFactors = FALSE)))
    }

    # Check cache
    dir.create(cache_dir, recursive = TRUE, showWarnings = FALSE)
    cache_file <- file.path(cache_dir, paste0(project_name, ".rds"))

    hashes <- vapply(r_files, file_hash, character(1))
    hash_key <- paste(sort(paste(basename(r_files), hashes)), collapse = "|")

    if (file.exists(cache_file)) {
        cached <- readRDS(cache_file)
        if (identical(cached$hash_key, hash_key)) {
            return(cached$result)
        }
    }

    # Get exported names from NAMESPACE if available
    ns_file <- file.path(project_dir, "NAMESPACE")
    exported_names <- character()
    if (file.exists(ns_file)) {
        ns_lines <- readLines(ns_file, warn = FALSE)
        # Match export(name) patterns
        m <- regmatches(ns_lines, regexec("^export\\(([^)]+)\\)", ns_lines))
        exported_names <- unlist(lapply(m, function(x) {
            if (length(x) > 1) x[2] else character()
        }))
        # Also match S3method(generic,class)
        m2 <- regmatches(ns_lines,
                         regexec("^S3method\\(([^,]+),([^)]+)\\)", ns_lines))
        s3_names <- unlist(lapply(m2, function(x) {
            if (length(x) > 1) paste0(x[2], ".", x[3]) else character()
        }))
        exported_names <- c(exported_names, s3_names)
    }

    all_defs <- data.frame(name = character(), file = character(),
                           line = integer(), exported = logical(),
                           stringsAsFactors = FALSE)
    all_calls <- data.frame(caller = character(), callee = character(),
                            file = character(), line = integer(),
                            stringsAsFactors = FALSE)

    for (fp in r_files) {
        rel_file <- basename(fp)
        parsed <- tryCatch({
            expr <- parse(fp, keep.source = TRUE)
            getParseData(expr, includeText = TRUE)
        }, error = function(e) NULL)

        if (is.null(parsed) || nrow(parsed) == 0L) {
            next
        }

        # Extract function definitions: SYMBOL followed by LEFT_ASSIGN/EQ_ASSIGN
        # then FUNCTION
        file_defs <- extract_defs(parsed, rel_file, exported_names)
        all_defs <- rbind(all_defs, file_defs)

        # Extract function calls
        file_calls <- extract_calls(parsed, rel_file, file_defs$name)
        all_calls <- rbind(all_calls, file_calls)
    }

    result <- list(defs = all_defs, calls = all_calls)

    # Cache
    saveRDS(list(hash_key = hash_key, result = result), cache_file)

    result
}

#' Extract function definitions from parse data
#' @noRd
extract_defs <- function(pd, file, exported_names) {
    # Strategy: find LEFT_ASSIGN/EQ_ASSIGN tokens, then look at siblings
    # of the parent expr. In R's parse tree:
    #   expr(parent) -> expr(lhs) -> SYMBOL, LEFT_ASSIGN, expr(rhs) -> FUNCTION
    assigns <- pd[pd$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN"),, drop = FALSE]
    defs <- data.frame(name = character(), file = character(),
                       line = integer(), exported = logical(),
                       stringsAsFactors = FALSE)

    for (i in seq_len(nrow(assigns))) {
        a <- assigns[i,]
        parent_id <- a$parent
        siblings <- pd[pd$parent == parent_id,, drop = FALSE]
        siblings <- siblings[order(siblings$line1, siblings$col1),, drop = FALSE]

        assign_pos <- which(siblings$id == a$id)
        if (assign_pos < 2L || assign_pos >= nrow(siblings)) {
            next
        }

        # LHS is an expr wrapper; look inside it for SYMBOL
        lhs_expr <- siblings[assign_pos - 1L,]
        if (lhs_expr$token == "SYMBOL") {
            fn_name <- lhs_expr$text
            fn_line <- lhs_expr$line1
        } else if (lhs_expr$token == "expr") {
            lhs_children <- pd[pd$parent == lhs_expr$id,, drop = FALSE]
            sym <- lhs_children[lhs_children$token == "SYMBOL",, drop = FALSE]
            if (nrow(sym) == 0L) {
                next
            }
            fn_name <- sym$text[1]
            fn_line <- sym$line1[1]
        } else {
            next
        }

        # RHS is an expr wrapper; look inside for FUNCTION token
        rhs_expr <- siblings[assign_pos + 1L,]
        has_function <- FALSE
        if (rhs_expr$token == "expr") {
            rhs_children <- pd[pd$parent == rhs_expr$id,, drop = FALSE]
            has_function <- any(rhs_children$token == "FUNCTION")
        }

        if (has_function) {
            defs <- rbind(defs,
                          data.frame(name = fn_name, file = file, line = fn_line,
                                     exported = fn_name %in% exported_names,
                                     stringsAsFactors = FALSE))
        }
    }

    defs
}

#' Extract function calls from parse data
#' @noRd
extract_calls <- function(pd, file, local_defs) {
    # Build a line-range map: for each function def, find the extent of its
    # top-level expr (the enclosing assignment expr)
    def_ranges <- build_def_ranges(pd, local_defs)

    # SYMBOL_FUNCTION_CALL tokens are function calls
    call_tokens <- pd[pd$token == "SYMBOL_FUNCTION_CALL",, drop = FALSE]

    # Also find namespace calls: pkg::fn
    ns_calls <- pd[pd$token == "NS_GET",, drop = FALSE]

    calls <- data.frame(caller = character(), callee = character(),
                        file = character(), line = integer(),
                        stringsAsFactors = FALSE)

    for (i in seq_len(nrow(call_tokens))) {
        ct <- call_tokens[i,]
        caller <- enclosing_def(ct$line1, def_ranges)
        calls <- rbind(calls,
                       data.frame(caller = caller, callee = ct$text, file = file,
                                  line = ct$line1, stringsAsFactors = FALSE))
    }

    for (i in seq_len(nrow(ns_calls))) {
        nc <- ns_calls[i,]
        parent_id <- nc$parent
        siblings <- pd[pd$parent == parent_id,, drop = FALSE]
        siblings <- siblings[order(siblings$line1, siblings$col1),, drop = FALSE]

        pkg_token <- siblings[siblings$token == "SYMBOL_PACKAGE",, drop = FALSE]
        fn_token <- siblings[siblings$token %in% c("SYMBOL_FUNCTION_CALL",
                "SYMBOL"),, drop = FALSE]

        if (nrow(pkg_token) > 0L && nrow(fn_token) > 0L) {
            caller <- enclosing_def(nc$line1, def_ranges)
            callee <- paste0(pkg_token$text[1], "::", fn_token$text[1])
            calls <- rbind(calls,
                           data.frame(caller = caller, callee = callee, file = file,
                                      line = nc$line1, stringsAsFactors = FALSE))
        }
    }

    calls
}

#' Build line-range map for function definitions
#' @noRd
build_def_ranges <- function(pd, local_defs) {
    if (length(local_defs) == 0L) {
        return(NULL)
    }

    assigns <- pd[pd$token %in% c("LEFT_ASSIGN", "EQ_ASSIGN"),, drop = FALSE]
    ranges <- data.frame(name = character(), start = integer(),
                         end = integer(), stringsAsFactors = FALSE)

    for (i in seq_len(nrow(assigns))) {
        a <- assigns[i,]
        parent_id <- a$parent
        parent_row <- pd[pd$id == parent_id,, drop = FALSE]
        if (nrow(parent_row) == 0L) {
            next
        }

        siblings <- pd[pd$parent == parent_id,, drop = FALSE]
        siblings <- siblings[order(siblings$line1, siblings$col1),, drop = FALSE]
        assign_pos <- which(siblings$id == a$id)
        if (assign_pos < 2L) {
            next
        }

        lhs_expr <- siblings[assign_pos - 1L,]
        fn_name <- NULL
        if (lhs_expr$token == "SYMBOL" && lhs_expr$text %in% local_defs) {
            fn_name <- lhs_expr$text
        } else if (lhs_expr$token == "expr") {
            lhs_children <- pd[pd$parent == lhs_expr$id,, drop = FALSE]
            sym <- lhs_children[lhs_children$token == "SYMBOL",, drop = FALSE]
            if (nrow(sym) > 0L && sym$text[1] %in% local_defs) {
                fn_name <- sym$text[1]
            }
        }

        if (!is.null(fn_name)) {
            ranges <- rbind(ranges,
                            data.frame(name = fn_name, start = parent_row$line1,
                                       end = parent_row$line2, stringsAsFactors = FALSE))
        }
    }

    ranges
}

#' Find which function definition encloses a line
#' @noRd
enclosing_def <- function(line, def_ranges) {
    if (is.null(def_ranges) || nrow(def_ranges) == 0L) {
        return("<top-level>")
    }
    inside <- def_ranges[def_ranges$start <= line &
        def_ranges$end >= line,, drop = FALSE]
    if (nrow(inside) == 0L) {
        return("<top-level>")
    }
    # If nested, pick the innermost (smallest range)
    inside$span <- inside$end - inside$start
    inside$name[which.min(inside$span)]
}

