#' Render the selected context fragments
#'
#' Returns included injectable fragments in manifest order, joined with two
#' newlines. Native and skipped sources are excluded. This is an explicit
#' request for source contents; printing a manifest or audit does not show them.
#' @param manifest A manifest returned by \code{\link{context_manifest}}.
#' @return A character string, or \code{""} when no fragments are included.
#' @examples
#' m <- context_manifest("corteza", discover = FALSE,
#'     extra_sources = list(list(id = "note", kind = "memory", text = "A note.")))
#' context_render(m)
#' @export
context_render <- function(manifest) {
    context_validate_manifest(manifest)
    ids <- manifest$sources$id[manifest$sources$included]
    paste(manifest$fragments[ids], collapse = "\n\n")
}

#' Audit context inclusion and token costs
#'
#' Reports metadata, exact duplicate sources, native overlap, missing or
#' unreadable files, audience exclusions, explicit truncation, and size
#' thresholds. Does not print or retain source bodies in its result, execute
#' snippets, or infer semantic contradictions from arbitrary text.
#' @param manifest A manifest returned by \code{\link{context_manifest}}.
#' @param layer_tokens Estimated-token warning threshold for one source.
#' @param total_tokens Estimated-token warning threshold for rendered context.
#' @return A \code{saber_context_audit} list with metadata-only sources,
#'   findings (source_id, code, severity, related_id), total emitted sizes,
#'   and the estimator label. Native tokens are not part of the emitted total.
#' @examples
#' m <- context_manifest("corteza", discover = FALSE,
#'     extra_sources = list(list(id = "note", kind = "memory", text = "A note.")))
#' context_audit(m, layer_tokens = 1)
#' @export
context_audit <- function(manifest, layer_tokens = 2000L,
                          total_tokens = 8000L) {
    context_validate_manifest(manifest)
    for (limit in list(layer_tokens, total_tokens)) {
        if (!is.numeric(limit) || length(limit) != 1L || is.na(limit) ||
            limit < 0) {
            stop("Audit thresholds must be nonnegative numbers or Inf.",
                 call. = FALSE)
        }
    }
    sources <- manifest$sources
    findings <- data.frame(source_id = character(), code = character(),
                           severity = character(), related_id = character())
    add <- function(id, code, severity = "warning", related = "") {
        findings[nrow(findings) + 1L,] <<- list(id, code, severity, related)
    }
    for (i in seq_len(nrow(sources))) {
        row <- sources[i,]
        if (row$status %in% c("missing", "unreadable")) {
            add(row$id, row$status)
        }
        if (nzchar(row$duplicate_of)) {
            if (row$reason == "native_autoload") {
                code <- "native_overlap"
            } else {
                code <- row$reason
            }
            add(row$id, code, "info", row$duplicate_of)
        } else if (nzchar(row$equivalent_to)) {
            related <- sources$delivery[match(row$equivalent_to, sources$id)]
            if (row$delivery == "native" && related == "native") {
                severity <- "warning"
            } else {
                severity <- "info"
            }

            add(row$id, row$equivalence, severity, row$equivalent_to)
        }
        if (row$reason == "audience_excluded") {
            add(row$id, "audience_excluded", "info")
        }
        if (row$delivery == "native" && !row$audience_matches) {
            add(row$id, "native_audience_mismatch")
        }
        if (isTRUE(row$source_tokens > layer_tokens)) {
            add(row$id, "oversized_source")
        }
        if (row$truncated) {
            add(row$id, "truncated")
        }
        if (row$delivery == "native" && !nzchar(row$native_evidence)) {
            add(row$id, "native_evidence_missing")
        }
    }
    total <- context_sizes(context_render(manifest))
    if (total[["tokens"]] > total_tokens) {
        add("", "oversized_total")
    }
    structure(list(agent = manifest$agent, sources = sources, findings = findings,
                   total = total, estimator = manifest$estimator),
              class = "saber_context_audit")
}

context_validate_manifest <- function(manifest) {
    if (!inherits(manifest, "saber_context_manifest") ||
        !identical(manifest$schema_version, 1L)) {
        stop("Expected a version 1 saber context manifest.", call. = FALSE)
    }
    sources <- manifest$sources
    if (!is.data.frame(sources) || !is.character(sources$id) ||
        anyNA(sources$id) || anyDuplicated(sources$id) ||
        !is.logical(sources$included) || anyNA(sources$included) ||
        !is.character(manifest$fragments) || anyNA(manifest$fragments) ||
        !identical(sources$id, names(manifest$fragments) %||% character())) {
        stop("Manifest source ids and fragments must remain aligned.",
             call. = FALSE)
    }
}

context_display_sources <- function(sources, abbreviate_home) {
    columns <- c("id", "kind", "delivery", "status", "included", "reason",
                 "source_chars", "source_lines", "source_tokens",
                 "emitted_tokens", "truncated", "budget", "omitted_chars",
                 "omitted_lines", "requested_path", "path", "source_hash")
    if (!"requested_path" %in% names(sources)) {
        columns <- setdiff(columns, "requested_path")
    }
    out <- sources[, columns, drop = FALSE]
    if (abbreviate_home) {
        for (name in intersect(c("id", "requested_path", "path"), columns)) {
            out[[name]] <- gsub(paste0(path.expand("~"), "/"), "~/", out[[name]], fixed = TRUE)
        }
    }
    out
}

#' @export
#' @noRd
#' @examples
#' print(context_manifest("corteza", discover = FALSE))
print.saber_context_manifest <- function(x, ..., abbreviate_home = TRUE) {
    context_flag(abbreviate_home, "abbreviate_home")
    cat("Context manifest for ", x$agent, " (", nrow(x$sources),
        " sources)\n", sep = "")
    print(context_display_sources(x$sources, abbreviate_home), row.names = FALSE)
    invisible(x)
}

#' @export
#' @noRd
#' @examples
#' print(context_audit(context_manifest("corteza", discover = FALSE)))
print.saber_context_audit <- function(x, ..., abbreviate_home = TRUE) {
    context_flag(abbreviate_home, "abbreviate_home")
    cat("Context audit for ", x$agent, ": ", x$total[["chars"]],
        " characters, about ", x$total[["tokens"]], " tokens emitted\n",
        sep = "")
    print(context_display_sources(x$sources, abbreviate_home), row.names = FALSE)
    if (nrow(x$findings)) {
        print(x$findings, row.names = FALSE)
    }
    invisible(x)
}
