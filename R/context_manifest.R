#' Build a source manifest for agent context
#'
#' Discovers shared and project instructions, records source provenance, and
#' selects context without changing the legacy \code{\link{agent_context}} API.
#' Printing the result shows metadata only. Source text is available through
#' \code{\link{context_render}} and the manifest's \code{fragments} field.
#'
#' @param agent Nonempty consumer name, such as \code{"corteza"}.
#' @param project_dir Project directory. Relative source paths resolve here.
#' @param workspace_dir Optional directory containing USER.md and SOUL.md.
#' @param shared_path Shared instruction file. NULL uses AGENTS_GLOBAL_MD,
#'   then ~/.config/agents/GLOBAL.md. FALSE disables shared-file discovery.
#' @param native_paths Character vector of files the caller confirms are
#'   already loaded by the consumer. These are measured but never reinjected.
#' @param extra_sources List of source descriptors, described below.
#' @param budgets Named list of budgets keyed by source id or kind. Each
#'   contains max_chars and/or max_lines, nonnegative integers or Inf.
#'   A source-id budget takes precedence over a kind budget. Kind budgets
#'   are shared by matching sources in rendering order.
#' @param discover Include standard shared, project, and workspace sources?
#'   FALSE uses only native_paths and extra_sources.
#' @return A \code{saber_context_manifest} list with schema_version, agent,
#'   project_dir, estimator, budgets, a sources data frame, and named
#'   fragments. The data frame records paths, audience, delivery, inclusion
#'   reasons, duplicate ids, source and emitted sizes/hashes, and budget loss.
#'   \code{requested_path} preserves the original source path, \code{path}
#'   resolves it against project_dir and expands tilde, and \code{canonical_path}
#'   resolves existing paths and symbolic links. Generated text uses empty paths.
#' @details
#' Discovery prefers AGENTS.md and falls back to CLAUDE.md when AGENTS.md is
#' missing, empty, or unreadable. Both candidates remain in the manifest.
#' Shared preferences and workspace USER.md are independent sources.
#' The Claude global file, memories, ancestor instructions, skills, and
#' briefings are not discovered implicitly. Supply those as explicit sources.
#' Native loading is declared by the caller, never inferred from agent alone.
#'
#' Each extra source is a list with a unique \code{id}, a \code{kind}, and
#' exactly one of \code{path} or scalar UTF-8 \code{text}. Optional fields are
#' \code{audience} (character vector, default \code{"*"}), \code{delivery}
#' (\code{"consumer"}, \code{"hook"}, or \code{"native"}), \code{origin},
#' \code{scope}, \code{config_path}, \code{native_evidence}, and numeric
#' \code{order}. Defaults preserve discovery then extra-source order; set
#' order to place generated layers before or between discovered sources.
#'
#' Files are read as UTF-8 without rewriting whitespace or line endings.
#' Deduplication compares canonical paths and exact bytes before budgets,
#' with native sources for the current audience taking precedence regardless
#' of order. Missing and unreadable native files can still suppress the same path,
#' but cannot establish equality to other files. MD5 fingerprints identify
#' content, not authenticity; byte equality confirms content matches.
#'
#' Budgets apply to emitted fragments, excluding the blank-line separators
#' inserted by context_render(). Native sources do not consume these budgets.
#' Truncation is recorded, with no unbudgeted marker inserted into the text.
#' By default nothing is truncated. Lines count physical lines, excluding an
#' empty line after a final newline; tokens are ceiling(characters / 4).
#' No source code is evaluated and no persistent cache is written.
#' @examples
#' m <- context_manifest("corteza", discover = FALSE,
#'     extra_sources = list(list(id = "runtime", kind = "runtime",
#'                              text = "R objects persist across turns.")))
#' context_audit(m)
#' cat(context_render(m))
#' @export
context_manifest <- function(agent, project_dir = getwd(),
                             workspace_dir = NULL, shared_path = NULL,
                             native_paths = character(),
                             extra_sources = list(), budgets = list(),
                             discover = TRUE) {
    context_string(agent, "agent")
    context_string(project_dir, "project_dir")
    context_flag(discover, "discover")
    if (!is.character(native_paths) || anyNA(native_paths) ||
        any(!nzchar(native_paths))) {
        stop("native_paths must contain nonempty paths.", call. = FALSE)
    }
    if (!is.list(extra_sources)) {
        stop("extra_sources must be a list of descriptors.", call. = FALSE)
    }
    project_dir <- normalizePath(context_path(project_dir, getwd()),
                                 mustWork = FALSE)
    specs <- context_discover(project_dir, workspace_dir, shared_path, discover)
    native_keys <- vapply(native_paths, function(path) {
        normalizePath(context_path(path, project_dir), mustWork = FALSE)
    }, "")
    native_paths <- native_paths[!duplicated(native_keys)]
    native <- lapply(native_paths, function(path) {
        list(id = paste0("native:", context_path(path, project_dir)),
             kind = "native", path = path, delivery = "native",
             native_evidence = "native_paths argument")
    })
    specs <- c(native, specs, extra_sources)
    specs <- lapply(seq_along(specs), function(i) {
        context_descriptor(specs[[i]], i, project_dir)
    })
    ids <- vapply(specs, `[[`, "", "id")
    if (anyDuplicated(ids)) {
        stop("Source ids must be unique.", call. = FALSE)
    }
    specs <- specs[order(vapply(specs, `[[`, 0, "order"), seq_along(specs))]
    budgets <- context_budgets(budgets, specs)
    loaded <- lapply(specs, context_read_source)
    selection <- context_select(specs, loaded, agent, budgets)
    structure(c(list(schema_version = 1L, agent = agent,
                     project_dir = project_dir, budgets = budgets,
                     estimator = "ceiling(characters / 4), version 1"), selection),
              class = "saber_context_manifest")
}

context_discover <- function(project_dir, workspace_dir, shared_path,
                             discover) {
    if (!discover) {
        return(list())
    }
    out <- list()
    if (!identical(shared_path, FALSE)) {
        if (is.null(shared_path)) {
            shared_path <- Sys.getenv("AGENTS_GLOBAL_MD", unset = "")
            if (!nzchar(shared_path)) {
                shared_path <- "~/.config/agents/GLOBAL.md"
            }
        }
        out <- list(list(id = "shared", kind = "shared", path = shared_path,
                         scope = "global"))
    }
    for (file in c("AGENTS.md", "CLAUDE.md")) {
        out <- c(out, list(list(id = paste0("project_", tolower(sub(".md", "", file, fixed = TRUE))),
                                kind = "project", path = file.path(project_dir, file),
                                scope = project_dir)))
    }
    attr(out[[length(out)]], "fallback_for") <- "project_agents"
    if (!is.null(workspace_dir)) {
        workspace_dir <- context_path(workspace_dir, project_dir)
        for (file in c("USER.md", "SOUL.md")) {
            out <- c(out, list(list(id = paste0("workspace_", tolower(sub(".md", "", file, fixed = TRUE))),
                                    kind = if (file == "SOUL.md") "identity" else "shared",
                                    path = file.path(workspace_dir, file), scope = workspace_dir)))
        }
    }
    out
}

context_descriptor <- function(x, index, project_dir) {
    fields <- c("id", "kind", "path", "text", "audience", "delivery",
                "origin", "scope", "config_path", "native_evidence",
                "order")
    if (!is.list(x) || is.null(names(x)) || anyDuplicated(names(x)) ||
        any(!names(x) %in% fields)) {
        stop("Invalid source descriptor fields.", call. = FALSE)
    }
    for (field in c("id", "kind")) {
        context_string(x[[field]], field)
    }
    if (sum(c("path", "text") %in% names(x)) != 1L) {
        stop("Each source requires exactly one of path or text.", call. = FALSE)
    }
    if ("path" %in% names(x)) {
        x$requested_path <- x$path
        x$path <- context_path(x$path, project_dir)
    } else {
        x$requested_path <- ""
        context_string(x$text, "text", empty = TRUE)
    }
    x$audience <- x$audience %||% "*"
    if (!is.character(x$audience) || !length(x$audience) ||
        anyNA(x$audience) || any(!nzchar(x$audience))) {
        stop("audience must contain nonempty consumer names.", call. = FALSE)
    }
    x$delivery <- x$delivery %||% "consumer"
    context_string(x$delivery, "delivery")
    if (!x$delivery %in% c("consumer", "hook", "native")) {
        stop("delivery must be consumer, hook, or native.", call. = FALSE)
    }
    for (field in c("origin", "scope", "config_path", "native_evidence")) {
        x[[field]] <- x[[field]] %||% ""
        context_string(x[[field]], field, empty = TRUE)
    }
    x$order <- x$order %||% index
    if (!is.numeric(x$order) || length(x$order) != 1L || !is.finite(x$order)) {
        stop("order must be a finite number.", call. = FALSE)
    }
    x
}
