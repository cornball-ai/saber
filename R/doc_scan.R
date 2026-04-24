#' @title Documentation scanning
#' @description Scan roxygen \verb{@examples} blocks and vignette code for
#'   function references.

#' Scan roxygen \verb{@examples} blocks for function calls
#'
#' Reads each \code{R/*.R} file in a project, extracts the contents of every
#' roxygen \verb{@examples} (or \verb{@examplesIf}) block, and returns rows
#' for lines that contain a call to \code{fn}. Detection is regex based:
#' \code{fn} must appear followed by an opening parenthesis and must not be
#' part of a longer identifier. \verb{pkg::fn(...)} calls match as well.
#'
#' The \code{caller} column is the name of the function being documented
#' (the first \code{name <- function(...)} line after the roxygen block), or
#' the empty string if none is detected.
#'
#' @param project_dir Path to the project root.
#' @param fn Function name to search for.
#' @return A data.frame with columns caller, project, file, line, source.
#' @noRd
scan_examples <- function(project_dir, fn) {
    project_name <- basename(normalizePath(project_dir, mustWork = FALSE))
    empty <- empty_doc_results()

    r_dir <- file.path(project_dir, "R")
    if (!dir.exists(r_dir)) {
        return(empty)
    }

    r_files <- list.files(r_dir, pattern = "\\.[Rr]$", full.names = TRUE)
    if (length(r_files) == 0L) {
        return(empty)
    }

    results <- empty
    for (fp in r_files) {
        lines <- readLines(fp, warn = FALSE)
        blocks <- extract_example_blocks(lines)
        for (b in blocks) {
            hits <- match_fn_lines(lines[b$line_nums], fn)
            if (length(hits) == 0L) {
                next
            }
            results <- rbind(results,
                             data.frame(caller = b$documented_fn,
                                        project = project_name,
                                        file = basename(fp),
                                        line = b$line_nums[hits],
                                        source = "example",
                                        stringsAsFactors = FALSE))
        }
    }

    results
}

#' Scan vignette code chunks for function calls
#'
#' Looks in \code{vignettes/} (and \code{inst/doc/}) for Rmd, qmd, and Rnw
#' files. Extracts R code chunks and flags lines that call \code{fn}.
#'
#' @param project_dir Path to the project root.
#' @param fn Function name to search for.
#' @return A data.frame with columns caller, project, file, line, source.
#' @noRd
scan_vignettes <- function(project_dir, fn) {
    project_name <- basename(normalizePath(project_dir, mustWork = FALSE))
    empty <- empty_doc_results()

    dirs <- file.path(project_dir, c("vignettes", "inst/doc"))
    dirs <- dirs[dir.exists(dirs)]
    if (length(dirs) == 0L) {
        return(empty)
    }

    files <- unlist(lapply(dirs, list.files,
                           pattern = "\\.(Rmd|rmd|qmd|Rnw|rnw)$",
                           full.names = TRUE, recursive = TRUE))
    if (length(files) == 0L) {
        return(empty)
    }

    results <- empty
    for (fp in files) {
        ext <- tolower(tools::file_ext(fp))
        lines <- readLines(fp, warn = FALSE)
        is_sweave <- ext %in% c("rnw")
        in_chunk <- chunk_mask(lines, is_sweave)

        code_line_nums <- which(in_chunk)
        if (length(code_line_nums) == 0L) {
            next
        }
        hits <- match_fn_lines(lines[code_line_nums], fn)
        if (length(hits) == 0L) {
            next
        }
        rel <- sub(paste0("^", project_dir, "/?"), "", fp, fixed = FALSE)
        results <- rbind(results,
                         data.frame(caller = "<vignette>",
                                    project = project_name,
                                    file = rel,
                                    line = code_line_nums[hits],
                                    source = "vignette",
                                    stringsAsFactors = FALSE))
    }

    results
}

#' Extract roxygen \verb{@examples} blocks from a file's lines
#'
#' Returns a list of blocks, each a list with components \code{line_nums}
#' (1-indexed file line numbers of the example body lines) and
#' \code{documented_fn} (the name of the function defined after the block,
#' or the empty string).
#'
#' @noRd
extract_example_blocks <- function(lines) {
    n <- length(lines)
    blocks <- list()
    i <- 1L
    tag_re <- "^#'\\s*@\\w+"
    ex_re <- "^#'\\s*@examples(If)?\\b"

    while (i <= n) {
        if (grepl(ex_re, lines[i])) {
            line_nums <- integer()
            # If @examplesIf has content after the condition, the body starts
            # on the next line anyway. Ignore the tag line itself.
            i <- i + 1L
            while (i <= n && grepl("^#'", lines[i])) {
                if (grepl(tag_re, lines[i])) {
                    break
                }
                line_nums <- c(line_nums, i)
                i <- i + 1L
            }

            documented_fn <- next_defined_fn(lines, i, n)
            blocks[[length(blocks) + 1L]] <- list(
                line_nums = line_nums,
                documented_fn = documented_fn
            )
        } else {
            i <- i + 1L
        }
    }

    blocks
}

#' Find the next top-level function definition after a given line
#'
#' Scans forward from \code{start} looking for a \code{name <- function}
#' (or \code{name = function}) assignment at top level. Returns the name or
#' the empty string if not found within a few lines of non-roxygen code.
#'
#' @noRd
next_defined_fn <- function(lines, start, n) {
    pattern <- "^\\s*([A-Za-z.][A-Za-z0-9._]*)\\s*(<-|=)\\s*function\\b"
    j <- start
    while (j <= n) {
        # Skip blank lines and roxygen lines (in case multiple blocks abut)
        if (!nzchar(trimws(lines[j])) || grepl("^#'", lines[j])) {
            j <- j + 1L
            next
        }
        m <- regmatches(lines[j], regexec(pattern, lines[j]))
        if (length(m[[1L]]) >= 2L) {
            return(m[[1L]][2L])
        }
        # First non-blank non-roxygen line wasn't a function def — give up
        return("")
    }
    ""
}

#' Build a per-line logical mask for "this line is inside an R code chunk"
#'
#' @param lines Character vector of file lines.
#' @param is_sweave If TRUE, parse Rnw \verb{<<>>=...@} chunks; otherwise
#'   Rmd/qmd \verb{```{r...}...```} chunks.
#' @return Logical vector of \code{length(lines)}.
#' @noRd
chunk_mask <- function(lines, is_sweave = FALSE) {
    n <- length(lines)
    inside <- logical(n)
    in_chunk <- FALSE

    if (is_sweave) {
        start_re <- "^<<.*>>="
        end_re <- "^@\\s*$"
    } else {
        start_re <- "^```\\{[rR]([, }]|$)"
        end_re <- "^```\\s*$"
    }

    for (i in seq_len(n)) {
        if (!in_chunk) {
            if (grepl(start_re, lines[i])) {
                in_chunk <- TRUE
            }
            next
        }
        # in_chunk is TRUE
        if (grepl(end_re, lines[i])) {
            in_chunk <- FALSE
            next
        }
        inside[i] <- TRUE
    }

    inside
}

#' Find 1-indexed positions within \code{lines} containing a call to \code{fn}
#'
#' Matches \code{fn} followed by optional whitespace and an opening paren,
#' with a negative lookbehind that rejects identifier characters (so
#' \code{myfn(} or \code{my.fn(} do not match, but \code{pkg::fn(} does).
#'
#' @noRd
match_fn_lines <- function(lines, fn) {
    if (length(lines) == 0L) {
        return(integer())
    }
    pattern <- paste0("(?<![A-Za-z0-9._])",
                      gsub("([.\\\\+*?\\[\\]^$(){}|])", "\\\\\\1", fn, perl = TRUE),
                      "\\s*\\(")
    which(grepl(pattern, lines, perl = TRUE))
}

#' Empty doc-scan result frame
#' @noRd
empty_doc_results <- function() {
    data.frame(caller = character(), project = character(),
               file = character(), line = integer(),
               source = character(), stringsAsFactors = FALSE)
}

