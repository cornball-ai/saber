# Selection, exact deduplication, and explicit fragment budgets.

context_budgets <- function(budgets, specs) {
    if (!is.list(budgets) || (length(budgets) &&
            (is.null(names(budgets)) || anyNA(names(budgets)) ||
                any(!nzchar(names(budgets))) ||
                anyDuplicated(names(budgets))))) {
        stop("budgets must be a named list.", call. = FALSE)
    }
    keys <- c(vapply(specs, `[[`, "", "id"), vapply(specs, `[[`, "", "kind"))
    if (any(!names(budgets) %in% keys)) {
        stop("Budget names must match a source id or kind.", call. = FALSE)
    }
    lapply(budgets, function(x) {
        if (!is.list(x) || !length(x) || is.null(names(x)) ||
            anyDuplicated(names(x)) ||
            any(!names(x) %in% c("max_chars", "max_lines"))) {
            stop("Each budget requires max_chars and/or max_lines.",
                 call. = FALSE)
        }
        for (value in x) {
            if (!is.numeric(value) || length(value) != 1L || is.na(value) ||
                value < 0 || value != floor(value)) {
                stop("Budget limits must be nonnegative integers or Inf.", call. = FALSE)
            }
        }
        list(max_chars = x$max_chars %||% Inf, max_lines = x$max_lines %||% Inf)
    })
}

context_duplicate <- function(input, loaded, candidates) {
    for (i in candidates) {
        other <- loaded[[i]]
        if (nzchar(input$canonical_path) &&
            identical(input$canonical_path, other$canonical_path)) {
            return(list(index = i, reason = "same_path"))
        }
    }
    for (i in candidates) {
        other <- loaded[[i]]
        if (!is.na(input$hash) && identical(input$hash, other$hash) &&
            identical(input$raw, other$raw)) {
            return(list(index = i, reason = "same_content"))
        }
    }
    NULL
}

context_cut <- function(text, chars, lines) {
    if (chars == 0 || lines == 0) {
        return("")
    }
    if (is.finite(lines)) {
        ends <- gregexpr("\n", text, fixed = TRUE)[[1L]]
        ends <- ends[ends > 0L]
        if (length(ends) >= lines) {
            text <- substr(text, 1L, ends[[lines]])
        }
    }
    if (is.finite(chars)) {
        text <- substr(text, 1L, chars)
    }
    text
}

context_budget_source <- function(row, text, remaining) {
    if (row$id %in% names(remaining)) {
        key <- row$id
    } else {
        key <- row$kind
    }
    if (!key %in% names(remaining)) {
        return(list(row = row, text = text, remaining = remaining))
    }
    limit <- remaining[[key]]
    cut <- context_cut(text, limit$max_chars, limit$max_lines)
    size <- context_sizes(cut)
    row$budget <- key
    row$max_chars <- limit$max_chars
    row$max_lines <- limit$max_lines
    row$omitted_chars <- nchar(text) - size[["chars"]]
    row$omitted_lines <- context_sizes(text)[["lines"]] - size[["lines"]]
    row$truncated <- !identical(text, cut)
    remaining[[key]]$max_chars <- limit$max_chars - size[["chars"]]
    remaining[[key]]$max_lines <- limit$max_lines - size[["lines"]]
    list(row = row, text = cut, remaining = remaining)
}

context_select <- function(specs, loaded, agent, budgets) {
    if (!length(specs)) {
        return(list(sources = context_empty_sources(), fragments = character()))
    }
    rows <- lapply(seq_along(specs),
                   function(i) context_source_row(specs[[i]], loaded[[i]]))
    native <- which(vapply(specs, function(x) {
        x$delivery == "native" && any(x$audience %in% c("*", agent))
    }, logical(1)))
    accepted <- integer()
    fragments <- structure(rep("", length(specs)), names = vapply(specs, `[[`, "", "id"))
    ids <- names(fragments)
    preferred <- match("project_agents", ids)
    fallback <- !is.na(preferred) && loaded[[preferred]]$status == "available"
    remaining <- budgets
    for (i in seq_along(specs)) {
        row <- rows[[i]]
        spec <- specs[[i]]
        input <- loaded[[i]]
        row$audience_matches <- any(spec$audience %in% c("*", agent))
        equivalent <- context_duplicate(input, loaded, seq_len(i - 1L))
        if (!is.null(equivalent)) {
            row$equivalent_to <- ids[[equivalent$index]]
            row$equivalence <- equivalent$reason
        }
        decision <- context_source_decision(spec, input, loaded, agent,
            native, accepted, fallback)
        row$reason <- decision$reason
        if (!is.null(decision$duplicate)) {
            row$duplicate_of <- ids[[decision$duplicate]]
        }
        if (row$reason == "included") {
            accepted <- c(accepted, i)
            limited <- context_budget_source(row, input$text, remaining)
            row <- limited$row
            remaining <- limited$remaining
            fragments[[i]] <- limited$text
            row$included <- nzchar(limited$text)
            if (!row$included) {
                row$reason <- "budget_exhausted"
            }
            size <- context_sizes(limited$text)
            row[1L, c("emitted_bytes", "emitted_chars", "emitted_lines", "emitted_tokens")] <- as.list(size)
            row$emitted_hash <- context_hash(charToRaw(enc2utf8(limited$text)))
        }
        rows[[i]] <- row
    }
    list(sources = do.call(rbind, rows), fragments = fragments)
}

context_source_decision <- function(spec, input, loaded, agent, native,
                                    accepted, fallback) {
    if (!any(spec$audience %in% c("*", agent))) {
        return(list(reason = "audience_excluded"))
    }
    if (spec$delivery == "native") {
        return(list(reason = "native_autoload"))
    }
    duplicate <- context_duplicate(input, loaded, native)
    if (!is.null(duplicate)) {
        return(list(reason = "native_autoload", duplicate = duplicate$index))
    }
    if (input$status != "available") {
        return(list(reason = input$status))
    }
    duplicate <- context_duplicate(input, loaded, accepted)
    if (!is.null(duplicate)) {
        return(list(reason = duplicate$reason, duplicate = duplicate$index))
    }
    if (identical(attr(spec, "fallback_for"), "project_agents") && fallback) {
        return(list(reason = "fallback_not_selected"))
    }
    list(reason = "included")
}
