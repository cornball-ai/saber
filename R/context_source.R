# Internal source reading and accounting. No persistent caches.

context_string <- function(x, name, empty = FALSE) {
    if (!is.character(x) || length(x) != 1L || is.na(x) ||
        (!empty && !nzchar(trimws(x)))) {
        stop(name, " must be a ", if (empty) "" else "nonempty ",
             "character string.", call. = FALSE)
    }
    invisible(x)
}

context_flag <- function(x, name) {
    if (!is.logical(x) || length(x) != 1L || is.na(x)) {
        stop(name, " must be TRUE or FALSE.", call. = FALSE)
    }
}

context_path <- function(path, project_dir) {
    context_string(path, "path")
    path <- path.expand(path)
    if (!grepl("^(/|[A-Za-z]:[/\\\\]|\\\\\\\\)", path)) {
        path <- file.path(project_dir, path)
    }
    path
}

context_hash <- function(bytes) {
    if ("bytes" %in% names(formals(tools::md5sum))) {
        return(do.call(tools::md5sum, list(bytes = bytes)))
    }
    context_hash_file(bytes)
}

context_hash_file <- function(bytes) {
    path <- tempfile("saber-context-")
    on.exit(unlink(path), add = TRUE)
    writeBin(bytes, path)
    unname(tools::md5sum(path))
}

context_sizes <- function(text) {
    c(bytes = nchar(text, type = "bytes"),
        chars = nchar(text, type = "chars"),
        lines = length(strsplit(text, "\n", fixed = TRUE)[[1L]]),
        tokens = ceiling(nchar(text, type = "chars") / 4))
}

context_read_source <- function(spec) {
    path <- spec$path %||% ""
    if (nzchar(path)) {
        canonical <- normalizePath(path, mustWork = FALSE)
    } else {
        canonical <- ""
    }
    result <- list(status = "available", path = path, canonical_path = canonical,
                   text = "", raw = raw(), hash = NA_character_,
                   sizes = c(bytes = NA_real_, chars = NA_real_, lines = NA_real_,
                             tokens = NA_real_))
    if (nzchar(path) && !file.exists(path)) {
        result$status <- "missing"
        return(result)
    }
    input <- tryCatch(suppressWarnings({
        if (nzchar(path)) {
            if (isTRUE(file.info(path)$isdir)) {
                stop("Not a file")
            }
            bytes <- readBin(path, "raw", n = file.info(path)$size)
        } else {
            bytes <- charToRaw(enc2utf8(spec$text))
        }
        text <- iconv(rawToChar(bytes), from = "UTF-8", to = "UTF-8", sub = NA)
        if (is.na(text)) {
            stop("Invalid UTF-8")
        }
        list(raw = bytes, text = text)
    }), error = function(e) NULL)
    if (is.null(input)) {
        result$status <- "unreadable"
        return(result)
    }
    result$raw <- input$raw
    result$text <- input$text
    result$hash <- context_hash(input$raw)
    result$sizes <- context_sizes(input$text)
    if (!nzchar(trimws(input$text))) {
        result$status <- "empty"
    }
    result
}

context_source_row <- function(spec, input) {
    data.frame(id = spec$id, kind = spec$kind, order = spec$order,
               path = input$path, canonical_path = input$canonical_path,
               audience = paste(spec$audience, collapse = ", "),
               delivery = spec$delivery, origin = spec$origin,
               scope = spec$scope, config_path = spec$config_path,
               native_evidence = spec$native_evidence, status = input$status,
               included = FALSE, reason = input$status, duplicate_of = "",
               equivalent_to = "", equivalence = "", audience_matches = TRUE,
               source_bytes = input$sizes[["bytes"]],
               source_chars = input$sizes[["chars"]],
               source_lines = input$sizes[["lines"]],
               source_tokens = input$sizes[["tokens"]],
               source_hash = input$hash, hash_algorithm = "md5",
               emitted_bytes = 0, emitted_chars = 0, emitted_lines = 0,
               emitted_tokens = 0, emitted_hash = NA_character_,
               truncated = FALSE, budget = "", max_chars = Inf,
               max_lines = Inf, omitted_chars = 0, omitted_lines = 0,
               stringsAsFactors = FALSE)
}

context_empty_sources <- function() {
    spec <- context_descriptor(list(id = "empty", kind = "empty", text = ""),
                               1L, ".")
    context_source_row(spec, context_read_source(spec))[FALSE,]
}
