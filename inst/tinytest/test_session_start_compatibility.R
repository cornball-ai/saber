# These are compatibility probes for the existing script, not a new API.
local({
    script <- system.file("scripts", "session-start.R", package = "saber")
    expressions <- parse(script)
    helpers <- new.env(parent = baseenv())
    wanted <- c("context_json_string", "native_shared_context")
    for (expression in expressions) {
        if (is.call(expression) && identical(expression[[1L]], as.name("<-")) &&
            as.character(expression[[2L]]) %in% wanted) {
            eval(expression, helpers)
        }
    }
    expect_true(all(vapply(wanted, exists, logical(1), envir = helpers,
                           inherits = FALSE)))
    # Every representable JSON control character, plus quotes, slashes and UTF-8.
    text <- paste0(intToUtf8(1:31), '"\\/', "\u00e9\U0001f642")
    encoded <- helpers$context_json_string(text)
    expect_false(any(utf8ToInt(encoded) < 32L))
    expect_identical(eval(parse(text = encoded)), text)
    expect_identical(helpers$context_json_string(""), '""')
    expect_identical(helpers$context_json_string("line\n\ttab\rend"),
                     '"line\\n\\ttab\\rend"')

    root <- tempfile("saber-native-shared-")
    dir.create(root)
    on.exit(unlink(root, recursive = TRUE), add = TRUE)
    claude <- file.path(root, "claude")
    codex <- file.path(root, "codex")
    dir.create(claude)
    dir.create(codex)
    helpers$Sys.getenv <- function(x, unset = "") {
        switch(x, CLAUDE_CONFIG_DIR = claude, CODEX_HOME = codex, unset)
    }
    shared <- file.path(root, "shared.md")
    writeLines("Fixture policy.", shared)
    expect_false(helpers$native_shared_context("claude", shared))
    expect_false(helpers$native_shared_context("codex", shared))
    expect_false(helpers$native_shared_context("corteza", shared))
    expect_false(helpers$native_shared_context(NULL, shared))
    claude_file <- file.path(claude, "CLAUDE.md")
    codex_file <- file.path(codex, "AGENTS.md")
    file.copy(shared, claude_file)
    # Equal contents without shared identity do not prove native coverage.
    expect_false(helpers$native_shared_context("claude", shared))
    unlink(claude_file)
    linked <- suppressWarnings(file.symlink(shared, claude_file))
    if (linked) {
        expect_true(helpers$native_shared_context("claude", shared))
        expect_false(helpers$native_shared_context("claude", paste0(shared, ".missing")))
        expect_false(helpers$native_shared_context("claude", root))
        expect_true(file.symlink(shared, codex_file))
        expect_true(helpers$native_shared_context("codex", shared))
        override <- file.path(codex, "AGENTS.override.md")
        writeLines("Different override.", override)
        expect_false(helpers$native_shared_context("codex", shared))
        writeLines(character(), override)
        expect_true(helpers$native_shared_context("codex", shared))
        unlink(override)
        expect_true(file.symlink(shared, override))
        expect_true(helpers$native_shared_context("codex", shared))
        unlink(shared)
        expect_false(helpers$native_shared_context("claude", shared))
        expect_false(helpers$native_shared_context("codex", shared))
    }

    # Public signatures and defaults used by existing downstream consumers.
    expect_identical(names(formals(agent_context)), c(
        "agent", "project_dir", "workspace_dir", "memory_base", "claude_global_path",
        "include_memory", "include_project", "include_global", "include_soul",
        "max_memory_lines"))
    expect_identical(formals(agent_context)$agent, NULL)
    expect_identical(formals(agent_context)$include_global, NULL)
    expect_identical(formals(agent_context)$max_memory_lines, 100L)
    expect_identical(names(formals(context_manifest)), c(
        "agent", "project_dir", "workspace_dir", "shared_path", "native_paths",
        "extra_sources", "budgets", "discover"))
    expect_identical(formals(context_manifest)$shared_path, NULL)
    expect_identical(formals(context_manifest)$discover, TRUE)
    expect_identical(saber:::agent_context_defaults("llamar"),
                     saber:::agent_context_defaults("corteza"))
})
