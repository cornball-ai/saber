# Explicit fixtures keep discovery away from the user's instruction files.
root <- tempfile("saber-context-")
dir.create(root)

source_text <- function(id, text, kind = "memory", ...) {
    c(list(id = id, kind = kind, text = text), list(...))
}
source_file <- function(id, path, kind = "memory", ...) {
    c(list(id = id, kind = kind, path = path), list(...))
}
manifest <- function(sources = list(), ...) {
    context_manifest("corteza", project_dir = root, discover = FALSE,
                     extra_sources = sources, ...)
}
row <- function(m, id) m$sources[match(id, m$sources$id), ]

m <- manifest()
expect_identical(context_render(m), "")
expect_identical(nrow(m$sources), 0L)
expect_identical(nrow(context_audit(m)$findings), 0L)
expect_equal(context_audit(m)$total, c(bytes = 0, chars = 0, lines = 0, tokens = 0))

# Explicit ordering and exact text preservation, including CRLF and UTF-8.
unicode <- "caf\u00e9\r\nnext\n"
m <- manifest(list(source_text("late", "after", order = 20),
                   source_text("early", unicode, order = -1)))
expect_identical(context_render(m), paste0(unicode, "\n\nafter"))
expect_identical(m$sources$id, c("early", "late"))
expect_equal(row(m, "early")$source_chars, 11)
expect_equal(row(m, "early")$source_bytes, 12)
expect_equal(row(m, "early")$source_lines, 2)
expect_identical(m, manifest(list(source_text("late", "after", order = 20),
                                  source_text("early", unicode, order = -1))))
expect_identical(saber:::context_hash(charToRaw("abc")), "900150983cd24fb0d6963f7d28e17f72")
expect_identical(saber:::context_hash_file(charToRaw("abc")), "900150983cd24fb0d6963f7d28e17f72")

# Exact bytes deduplicate; whitespace differences remain separate.
m <- manifest(list(source_text("a", "same"), source_text("b", "same"),
                   source_text("c", "same\n")))
expect_identical(context_render(m), "same\n\nsame\n")
expect_identical(row(m, "b")$reason, "same_content")
expect_identical(row(m, "b")$duplicate_of, "a")
expect_true("same_content" %in% context_audit(m)$findings$code)

first <- file.path(root, "first.md")
copy <- file.path(root, "copy.md")
writeLines("private text", first)
file.copy(first, copy)
m <- manifest(list(source_file("a", first), source_file("b", copy)))
expect_identical(row(m, "b")$reason, "same_content")
expect_identical(row(m, "a")$source_hash, unname(tools::md5sum(first)))
expect_identical(row(m, "a")$source_hash, row(m, "a")$emitted_hash)
expect_identical(context_render(m), "private text\n")
m <- manifest(list(source_file("a", first)), native_paths = c("first.md", first))
expect_identical(context_render(m), "")
expect_equal(sum(m$sources$delivery == "native"), 1)

# Native coverage has priority even when declared after an injectable copy.
m <- manifest(list(source_file("inject", copy, order = 1),
                   source_file("native", first, delivery = "native", order = 100,
                               native_evidence = "test consumer v1")))
expect_identical(context_render(m), "")
expect_identical(row(m, "inject")$reason, "native_autoload")
expect_identical(row(m, "inject")$duplicate_of, "native")
expect_true("native_overlap" %in% context_audit(m)$findings$code)
expect_equal(context_audit(m)$total[["tokens"]], 0)

# Coverage for another consumer cannot suppress this consumer's context.
foreign_native <- source_text("claude_native", "shared instructions",
                              delivery = "native",
                              audience = c("claude", "codex"))
injectable <- source_text("corteza_context", "shared instructions",
                          audience = "corteza")
for (sources in list(list(foreign_native, injectable),
                     list(injectable, foreign_native))) {
    m <- manifest(sources)
    expect_identical(context_render(m), "shared instructions")
    expect_identical(row(m, "corteza_context")$reason, "included")
    expect_identical(row(m, "corteza_context")$duplicate_of, "")
    expect_identical(row(m, "claude_native")$reason, "audience_excluded")
    expect_false("native_overlap" %in% context_audit(m)$findings$code)
}
for (audience in list("*", c("claude", "corteza"))) {
    matching_native <- foreign_native
    matching_native$audience <- audience
    m <- manifest(list(injectable, matching_native))
    expect_identical(context_render(m), "")
    expect_identical(row(m, "corteza_context")$duplicate_of, "claude_native")
}
for (path in c(first, copy)) {
    m <- manifest(list(source_file("claude_native", first,
                                   delivery = "native", audience = "claude"),
                       source_file("inject", path)))
    expect_identical(context_render(m), "private text\n")
    expect_true(row(m, "inject")$included)
}

# Preserve the literal source path separately from resolution and identity.
m <- manifest(list(source_file("relative", "./first.md")),
              native_paths = "first.md")
expect_identical(row(m, "relative")$requested_path, "./first.md")
expect_identical(row(m, "relative")$path, file.path(root, "./first.md"))
expect_identical(row(m, "relative")$canonical_path, normalizePath(first))
expect_identical(m$sources$requested_path[m$sources$delivery == "native"],
                 "first.md")
home_relative <- paste0("~/", basename(root), "/missing.md")
m <- manifest(list(source_file("home_relative", home_relative),
                   source_text("generated", "context")))
expect_identical(row(m, "home_relative")$requested_path, home_relative)
expect_identical(row(m, "home_relative")$path, path.expand(home_relative))
expect_identical(row(m, "generated")$requested_path, "")

# Earlier manifest snapshots remain renderable and printable.
older <- m
older$sources$requested_path <- NULL
expect_identical(context_render(older), context_render(m))
expect_true(length(capture.output(print(older))) > 0L)
expect_true(length(capture.output(print(context_audit(older)))) > 0L)

if (.Platform$OS.type != "windows") {
    link <- file.path(root, "link.md")
    linked <- file.symlink(first, link)
    if (linked) {
        m <- manifest(list(source_file("inject", link)), native_paths = first)
        expect_identical(context_render(m), "")
        expect_identical(row(m, "inject")$canonical_path, normalizePath(first))
        m <- manifest(list(source_file("a", first), source_file("b", link)))
        expect_identical(row(m, "b")$reason, "same_path")
    }
}

# Missing, directory, invalid UTF-8, empty, and excluded sources are inspectable.
missing <- file.path(root, "absent.md")
invalid <- file.path(root, "invalid.md")
writeBin(as.raw(c(0xff, 0xfe)), invalid)
m <- manifest(list(source_file("missing", missing), source_file("directory", root),
                   source_file("invalid", invalid), source_text("empty", " \n"),
                   source_text("claude_only", "must not render", audience = "claude")))
expect_identical(m$sources$status, c("missing", "unreadable", "unreadable", "empty", "available"))
expect_identical(row(m, "claude_only")$reason, "audience_excluded")
expect_identical(context_render(m), "")
expect_true(all(c("missing", "unreadable", "audience_excluded") %in% context_audit(m)$findings$code))

# Even unavailable native paths carry a declared suppression decision.
m <- manifest(list(source_file("missing", missing)), native_paths = missing)
expect_identical(row(m, "missing")$reason, "native_autoload")
expect_identical(row(m, "missing")$status, "missing")

# Deduplication does not depend on source inclusion or audience.
m <- manifest(list(source_text("a", "excluded", audience = "claude"),
                   source_text("b", "excluded", audience = "claude")))
expect_identical(row(m, "b")$equivalence, "same_content")
expect_true("same_content" %in% context_audit(m)$findings$code)
m <- manifest(list(source_text("native", "host loaded", audience = "claude", delivery = "native")))
expect_true(all(c("native_evidence_missing", "native_audience_mismatch") %in% context_audit(m)$findings$code))

# Kind budgets are cumulative. An explicit id budget overrides that pool.
m <- manifest(list(source_text("a", "alpha\nbeta\n"), source_text("b", "gamma")),
              budgets = list(memory = list(max_lines = 1)))
expect_identical(context_render(m), "alpha\n")
expect_true(all(m$sources$truncated))
expect_equal(row(m, "a")$omitted_chars, 5)
expect_equal(row(m, "a")$omitted_lines, 1)
expect_identical(row(m, "b")$reason, "budget_exhausted")
expect_equal(row(m, "b")$max_lines, 0)
expect_true(all(context_audit(m)$findings$code == "truncated"))

m <- manifest(list(source_text("a", "12345"), source_text("b", "abcdef"), source_text("c", "ghi")),
              budgets = list(memory = list(max_chars = 7), b = list(max_chars = 2)))
expect_identical(context_render(m), "12345\n\nab\n\ngh")
expect_identical(m$sources$budget, c("memory", "b", "memory"))
expect_equal(context_audit(m)$total[["chars"]], 13)
expect_equal(row(m, "c")$max_chars, 2)
expect_false(row(m, "b")$source_hash == row(m, "b")$emitted_hash)

m <- manifest(list(source_text("a", "\u00e9bc")), budgets = list(a = list(max_chars = 1)))
expect_identical(context_render(m), "\u00e9")
expect_equal(row(m, "a")$emitted_chars, 1)
expect_equal(row(m, "a")$emitted_bytes, 2)
m <- manifest(list(source_text("a", "abc")), budgets = list(memory = list(max_chars = 0)))
expect_identical(context_render(m), "")
expect_identical(row(m, "a")$reason, "budget_exhausted")
m <- manifest(list(source_text("a", "abc")), budgets = list(memory = list(max_chars = Inf)))
expect_identical(context_render(m), "abc")
expect_false(row(m, "a")$truncated)

# Canonical discovery is separate from the legacy global fallback.
agents <- file.path(root, "AGENTS.md")
claude <- file.path(root, "CLAUDE.md")
shared <- file.path(root, "GLOBAL.md")
workspace <- file.path(root, "workspace")
dir.create(workspace)
writeLines("shared rules", shared)
writeLines("project agents", agents)
writeLines("project claude", claude)
writeLines("workspace user", file.path(workspace, "USER.md"))
writeLines("workspace identity", file.path(workspace, "SOUL.md"))
discovered <- function(agent = "corteza", ...) {
    context_manifest(agent, root, shared_path = shared, workspace_dir = workspace, ...)
}
m <- discovered()
expect_identical(m$sources$id, c("shared", "project_agents", "project_claude", "workspace_user", "workspace_soul"))
expect_identical(row(m, "project_claude")$reason, "fallback_not_selected")
expect_identical(context_render(m), "shared rules\n\n\nproject agents\n\n\nworkspace user\n\n\nworkspace identity\n")
expect_false(any(grepl(".claude/CLAUDE.md", m$sources$path, fixed = TRUE)))

# The caller, not a consumer-name heuristic, declares native coverage.
codex <- discovered("codex", native_paths = agents)
expect_identical(row(codex, "project_agents")$reason, "native_autoload")
expect_false(grepl("project agents", context_render(codex), fixed = TRUE))
claude_manifest <- discovered("claude", native_paths = claude)
expect_true(grepl("project agents", context_render(claude_manifest), fixed = TRUE))
expect_identical(row(claude_manifest, "project_claude")$reason, "native_autoload")
expect_true(grepl("project agents", context_render(discovered("codex")), fixed = TRUE))

writeLines(character(), agents)
m <- discovered()
expect_true(row(m, "project_claude")$included)
expect_identical(row(m, "project_agents")$status, "empty")
file.remove(agents)
m <- discovered()
expect_identical(row(m, "project_agents")$status, "missing")
expect_true(row(m, "project_claude")$included)
if (.Platform$OS.type != "windows" && file.symlink(claude, agents)) {
    m <- discovered()
    expect_identical(row(m, "project_claude")$reason, "same_path")
    m <- discovered("claude", native_paths = claude)
    expect_identical(row(m, "project_agents")$reason, "native_autoload")
}

Sys.setenv(AGENTS_GLOBAL_MD = shared)
m <- context_manifest("corteza", root)
expect_true(grepl("shared rules", context_render(m), fixed = TRUE))
m <- context_manifest("corteza", root, shared_path = FALSE)
expect_false("shared" %in% m$sources$id)

# Same-basename projects cannot select each other's memory implicitly.
other <- file.path(root, "other", basename(root))
dir.create(other, recursive = TRUE)
m <- context_manifest("corteza", other, shared_path = FALSE)
expect_false(any(m$sources$kind == "memory"))
expect_identical(context_render(m), "")

# Both default print methods and the audit object omit source contents.
secret <- "SECRET_SENTINEL_do_not_print"
m <- manifest(list(source_text("runtime", secret, kind = "runtime")))
printed <- capture.output(print(m))
audit <- context_audit(m, layer_tokens = 1, total_tokens = 1)
expect_false(any(grepl(secret, printed, fixed = TRUE)))
expect_false(any(grepl(secret, capture.output(print(audit)), fixed = TRUE)))
expect_false(any(grepl(secret, capture.output(dput(unclass(audit))), fixed = TRUE)))
expect_true(all(c("oversized_source", "oversized_total") %in% audit$findings$code))
expect_identical(context_render(m), secret)

# Explicit composition has no magic behavior based on caller-selected ids.
explicit <- manifest(list(source_text("project_agents", "first"),
                          source_text("project_claude", "second")))
expect_identical(context_render(explicit), "first\n\nsecond")
broken <- m
broken$fragments <- NULL
expect_error(context_render(broken))

# Reject malformed inputs instead of silently changing routing or budgets.
expect_error(context_manifest(NULL, discover = FALSE))
expect_error(manifest(list(source_text("a", NA_character_))))
expect_error(manifest(list(list(id = "a", kind = "memory", path = first, text = "x"))))
expect_error(manifest(list(list(id = "a", kind = "memory", txt = "typo"))))
expect_error(manifest(list(source_text("a", "x"), source_text("a", "y"))))
expect_error(manifest(list(source_text("a", "x", audience = character()))))
expect_error(manifest(list(source_text("a", "x", delivery = "guess"))))
expect_error(manifest(list(source_text("a", "x", order = NA_real_))))
expect_error(manifest(list(source_text("a", "x")), budgets = list(typo = list(max_lines = 1))))
expect_error(manifest(list(source_text("a", "x")), budgets = list(memory = list(max_lines = -1))))
expect_error(manifest(list(source_text("a", "x")), budgets = list(memory = list(max_lines = 0.5))))
expect_error(manifest(list(source_text("a", "x")), budgets = list(memory = list(max_tokens = 1))))
expect_error(context_render(list()))
expect_error(context_audit(m, layer_tokens = NA_real_))

unlink(root, recursive = TRUE)
