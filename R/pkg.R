#' @title Package introspection
#' @description Query installed R packages for exported functions, internal
#'   functions, and help documentation.

#' List exported functions of a package
#'
#' Returns a data.frame of exported functions with their argument signatures.
#'
#' @param package Character. Package name.
#' @param pattern Optional regex to filter function names.
#' @return A data.frame with columns: name, args.
#' @examples
#' pkg_exports("tools")
#' pkg_exports("tools", pattern = "^Rd")
#' @export
pkg_exports <- function(package, pattern = NULL) {
    ns <- tryCatch(
                   getNamespace(package),
                   error = function(e) {
        stop("Package '", package, "' not found. Is it installed?",
             call. = FALSE)
    }
    )

    exports <- getNamespaceExports(ns)

    # Filter to functions only
    export_fns <- Filter(function(nm) {
        obj <- tryCatch(get(nm, envir = ns), error = function(e) NULL)
        is.function(obj)
    }, exports)

    if (!is.null(pattern)) {
        export_fns <- grep(pattern, export_fns, value = TRUE)
    }

    if (length(export_fns) == 0L) {
        return(data.frame(name = character(), args = character(),
                          stringsAsFactors = FALSE))
    }

    args_list <- vapply(export_fns, function(nm) {
        fn <- get(nm, envir = ns)
        paste(names(formals(fn)), collapse = ", ")
    }, character(1))

    data.frame(name = sort(export_fns), args = args_list[order(export_fns)],
               stringsAsFactors = FALSE, row.names = NULL)
}

#' List internal (non-exported) functions of a package
#'
#' Returns functions defined in a package namespace but not exported.
#'
#' @param package Character. Package name.
#' @param pattern Optional regex to filter function names.
#' @return A data.frame with columns: name, args.
#' @examples
#' pkg_internals("tools", pattern = "^check")
#' @export
pkg_internals <- function(package, pattern = NULL) {
    ns <- tryCatch(
                   getNamespace(package),
                   error = function(e) {
        stop("Package '", package, "' not found. Is it installed?",
             call. = FALSE)
    }
    )

    exports <- getNamespaceExports(ns)
    all_names <- ls(ns, all.names = TRUE)
    internal_names <- setdiff(all_names, exports)

    internal_fns <- Filter(function(nm) {
        obj <- get(nm, envir = ns)
        is.function(obj)
    }, internal_names)

    if (!is.null(pattern)) {
        internal_fns <- grep(pattern, internal_fns, value = TRUE)
    }

    if (length(internal_fns) == 0L) {
        return(data.frame(name = character(), args = character(),
                          stringsAsFactors = FALSE))
    }

    args_list <- vapply(internal_fns, function(nm) {
        fn <- get(nm, envir = ns)
        paste(names(formals(fn)), collapse = ", ")
    }, character(1))

    data.frame(name = sort(internal_fns),
               args = args_list[order(internal_fns)],
               stringsAsFactors = FALSE, row.names = NULL)
}

#' Get help for a package topic as markdown
#'
#' Extracts help documentation and converts it to clean markdown.
#'
#' @param topic Character. The help topic name.
#' @param package Character. Package name.
#' @param format Character. Output format: \code{"md"} (default) for plain
#'   markdown, or \code{"hugo"} for Hugo-compatible markdown with YAML front
#'   matter.
#' @return Character string of markdown help text.
#' @examples
#' cat(pkg_help("md5sum", "tools"))
#' @export
pkg_help <- function(topic, package, format = c("md", "hugo")) {
    format <- match.arg(format)
    db <- tools::Rd_db(package)

    rd_name <- paste0(topic, ".Rd")
    if (!rd_name %in% names(db)) {
        # Try alias match
        for (nm in names(db)) {
            rd <- db[[nm]]
            aliases <- rd_get_aliases(rd)
            if (topic %in% aliases) {
                rd_name <- nm
                break
            }
        }
    }

    if (!rd_name %in% names(db)) {
        stop("Topic '", topic, "' not found in package '", package, "'.",
             call. = FALSE)
    }

    rd <- db[[rd_name]]
    if (format == "hugo") {
        rd2hugo(rd, topic, package)
    } else {
        rd2md(rd)
    }
}

# --- Internal Rd-to-markdown conversion ---

#' Convert Rd object to markdown
#' @noRd
rd2md <- function(rd) {
    sections <- list()

    for (element in rd) {
        tag <- attr(element, "Rd_tag")
        if (is.null(tag)) {
            next
        }

        switch(tag,
               "\\title" = {
            sections$title <- trimws(rd_to_text(element))
        },
               "\\description" = {
            sections$description <- rd_to_md(element)
        },
               "\\usage" = {
            sections$usage <- rd_verbatim(element)
        },
               "\\arguments" = {
            sections$arguments <- rd_args_to_md(element)
        },
               "\\value" = {
            sections$value <- rd_to_md(element)
        },
               "\\details" = {
            sections$details <- rd_to_md(element)
        },
               "\\examples" = {
            sections$examples <- rd_verbatim(element)
        },
               "\\seealso" = {
            sections$seealso <- rd_to_md(element)
        },
               "\\references" = {
            sections$references <- rd_to_md(element)
        },
               "\\author" = {
            sections$author <- rd_to_md(element)
        },
               "\\note" = {
            sections$note <- rd_to_md(element)
        },
               "\\section" = {
            sec_title <- rd_to_text(element[[1]])
            sec_content <- rd_to_md(element[-1])
            if (is.null(sections$custom_sections)) {
                sections$custom_sections <- list()
            }
            sections$custom_sections <- c(sections$custom_sections,
                list(list(title = sec_title, content = sec_content)))
        }
        )
    }

    lines <- character()
    if (!is.null(sections$title)) {
        lines <- c(lines, paste0("### ", sections$title), "")
    }
    if (!is.null(sections$description)) {
        lines <- c(lines, "#### Description", "", sections$description, "")
    }
    if (!is.null(sections$usage)) {
        lines <- c(lines, "#### Usage", "", "```r", sections$usage, "```", "")
    }
    if (!is.null(sections$arguments)) {
        lines <- c(lines, "#### Arguments", "", sections$arguments, "")
    }
    if (!is.null(sections$details)) {
        lines <- c(lines, "#### Details", "", sections$details, "")
    }
    if (!is.null(sections$value)) {
        lines <- c(lines, "#### Value", "", sections$value, "")
    }
    if (!is.null(sections$custom_sections)) {
        for (sec in sections$custom_sections) {
            lines <- c(lines, paste0("#### ", sec$title), "", sec$content, "")
        }
    }
    if (!is.null(sections$note)) {
        lines <- c(lines, "#### Note", "", sections$note, "")
    }
    if (!is.null(sections$seealso)) {
        lines <- c(lines, "#### See Also", "", sections$seealso, "")
    }
    if (!is.null(sections$references)) {
        lines <- c(lines, "#### References", "", sections$references, "")
    }
    if (!is.null(sections$author)) {
        lines <- c(lines, "#### Author", "", sections$author, "")
    }
    if (!is.null(sections$examples)) {
        lines <- c(lines, "#### Examples", "", "```r", sections$examples,
                   "```", "")
    }

    paste(lines, collapse = "\n")
}

#' Convert Rd object to Hugo-compatible markdown
#' @noRd
rd2hugo <- function(rd, topic, package) {
    title <- ""
    description <- ""
    for (element in rd) {
        tag <- attr(element, "Rd_tag")
        if (identical(tag, "\\title")) {
            title <- trimws(rd_to_text(element))
        }
        if (identical(tag, "\\description")) {
            description <- trimws(rd_to_md(element))
        }
    }

    body <- rd2md(rd)

    front <- paste0("---\n", "title: \"", topic, "\"\n", "package: \"",
                    package, "\"\n", "description: >-\n", "  ",
                    gsub("\n", " ", description), "\n", "---\n")

    paste0(front, "\n", body)
}

#' Extract plain text from Rd element
#' @noRd
rd_to_text <- function(element) {
    if (is.character(element)) {
        return(element)
    }
    paste(unlist(lapply(element, rd_to_text)), collapse = "")
}

#' Convert Rd content to markdown with tag handling
#' @noRd
rd_to_md <- function(element) {
    if (is.character(element)) {
        return(element)
    }

    result <- character()
    for (child in element) {
        tag <- attr(child, "Rd_tag")
        if (is.null(tag)) {
            if (is.character(child)) {
                result <- c(result, child)
            } else {
                result <- c(result, rd_to_md(child))
            }
        } else {
            content <- rd_to_text(child)
            md <- switch(tag,
                         "\\code" = paste0("`", content, "`"),
                         "\\link" = paste0("`", content, "`"),
                         "\\linkS4class" = paste0("`", content, "`"),
                         "\\pkg" = paste0("**", content, "**"),
                         "\\emph" = paste0("*", content, "*"),
                         "\\strong" = paste0("**", content, "**"),
                         "\\bold" = paste0("**", content, "**"),
                         "\\sQuote" = paste0("'", content, "'"),
                         "\\dQuote" = paste0("\"", content, "\""),
                         "\\file" = paste0("`", content, "`"),
                         "\\url" = content,
                         "\\href" = {
                if (length(child) >= 2) {
                    url <- rd_to_text(child[[1]])
                    text <- rd_to_text(child[[2]])
                    paste0("[", text, "](", url, ")")
                } else {
                    content
                }
            },
                         "\\email" = content,
                         "\\var" = paste0("*", content, "*"),
                         "\\env" = paste0("`", content, "`"),
                         "\\option" = paste0("`", content, "`"),
                         "\\command" = paste0("`", content, "`"),
                         "\\dfn" = paste0("*", content, "*"),
                         "\\acronym" = content,
                         "\\dots" = "...",
                         "\\ldots" = "...",
                         "\\cr" = "\n",
                         "\\tab" = "\t",
                         "\\R" = "R",
                         "\\describe" = rd_describe_to_md(child),
                         "\\itemize" = rd_itemize_to_md(child),
                         "\\enumerate" = rd_enumerate_to_md(child),
                         "\\item" = rd_to_md(child),
                         "RCODE" = content,
                         "TEXT" = content,
                         "VERB" = content,
                         "COMMENT" = "",
                         rd_to_md(child)
            )
            result <- c(result, md)
        }
    }

    text <- paste(result, collapse = "")
    text <- rd_postprocess(text)
    trimws(text)
}

#' Extract verbatim text (usage, examples)
#' @noRd
rd_verbatim <- function(element) {
    text <- rd_to_text(element)
    gsub("^\\n+|\\n+$", "", text)
}

#' Convert \\arguments to markdown
#' @noRd
rd_args_to_md <- function(element) {
    lines <- character()
    for (child in element) {
        tag <- attr(child, "Rd_tag")
        if (identical(tag, "\\item") && length(child) >= 2) {
            arg_name <- rd_to_text(child[[1]])
            arg_desc <- rd_to_md(child[[2]])
            lines <- c(lines, paste0("- **`", arg_name, "`**: ", arg_desc))
        }
    }
    paste(lines, collapse = "\n")
}

#' Convert \\describe to markdown
#' @noRd
rd_describe_to_md <- function(element) {
    lines <- character()
    for (child in element) {
        tag <- attr(child, "Rd_tag")
        if (identical(tag, "\\item") && length(child) >= 2) {
            item_name <- rd_to_text(child[[1]])
            item_desc <- rd_to_md(child[[2]])
            lines <- c(lines, paste0("- **", item_name, "**: ", item_desc))
        }
    }
    paste(lines, collapse = "\n")
}

#' Convert \\itemize to markdown
#' @noRd
rd_itemize_to_md <- function(element) {
    lines <- character()
    for (child in element) {
        tag <- attr(child, "Rd_tag")
        if (identical(tag, "\\item")) {
            lines <- c(lines, paste0("- ", rd_to_md(child)))
        }
    }
    paste(lines, collapse = "\n")
}

#' Convert \\enumerate to markdown
#' @noRd
rd_enumerate_to_md <- function(element) {
    lines <- character()
    i <- 1L
    for (child in element) {
        tag <- attr(child, "Rd_tag")
        if (identical(tag, "\\item")) {
            lines <- c(lines, paste0(i, ". ", rd_to_md(child)))
            i <- i + 1L
        }
    }
    paste(lines, collapse = "\n")
}

#' Post-process text with embedded Rd markup
#' @noRd
rd_postprocess <- function(text) {
    text <- gsub("\\\\describe\\{\\s*\n?", "", text)
    text <- gsub("\\s*\\\\item\\{([^}]+)\\}\\{([^}]+)\\}", "\n- **\\1**: \\2",
                 text)
    text <- gsub("\n\\s*\\}\n", "\n", text)
    text <- gsub("^\\s*\\}\\s*$", "", text)
    text <- gsub("\\\\code\\{([^}]+)\\}", "`\\1`", text)
    text <- gsub("\\\\link\\{([^}]+)\\}", "`\\1`", text)
    text <- gsub("\\\\emph\\{([^}]+)\\}", "*\\1*", text)
    text <- gsub("\\\\strong\\{([^}]+)\\}", "**\\1**", text)
    text <- gsub("\\\\bold\\{([^}]+)\\}", "**\\1**", text)
    text <- gsub("\\\\pkg\\{([^}]+)\\}", "**\\1**", text)
    text <- gsub("\\\\file\\{([^}]+)\\}", "`\\1`", text)
    text <- gsub("\\\\sQuote\\{([^}]+)\\}", "'\\1'", text)
    text <- gsub("\\\\dQuote\\{([^}]+)\\}", "\"\\1\"", text)
    text <- gsub("\\\\dots\\b", "...", text)
    text <- gsub("\\\\ldots\\b", "...", text)
    text <- gsub("\\\\R\\b", "R", text)
    text <- gsub("\n{3,}", "\n\n", text)
    trimws(text)
}

#' Get aliases from Rd object
#' @noRd
rd_get_aliases <- function(rd) {
    aliases <- character()
    for (tag in rd) {
        if (identical(attr(tag, "Rd_tag"), "\\alias")) {
            aliases <- c(aliases, as.character(tag))
        }
    }
    trimws(aliases)
}

