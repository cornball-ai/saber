# Tests for session-start hook script.
# Exercises the hook end-to-end via a child Rscript with HOME / CODEX_HOME
# redirected. The system2(env =) plumbing is not honored consistently on
# Windows (env vars get passed as positional args to Rscript), so this is
# gated to dev runs only.
if (!at_home()) exit_file("Session-start hook is *nix dev-only.")

scan_dir <- file.path(tempdir(), "test_session_start")
pkg_dir <- file.path(scan_dir, "hookpkg")
sub_dir <- file.path(pkg_dir, "R")
dir.create(sub_dir, recursive = TRUE, showWarnings = FALSE)

writeLines(c(
    "Package: hookpkg",
    "Title: Hook Package",
    "Version: 0.1.0"
), file.path(pkg_dir, "DESCRIPTION"))
writeLines("hook_fn <- function() NULL", file.path(sub_dir, "hook.R"))

system2("git", c("-C", pkg_dir, "init", "-q"), stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "config", "user.email", "test@test.com"),
        stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "config", "user.name", "Test"),
        stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "add", "-A"), stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "commit", "-q", "-m", "init"),
        stdout = FALSE, stderr = FALSE)

script <- system.file("scripts", "session-start.R", package = "saber")
old_wd <- getwd()
on.exit(setwd(old_wd), add = TRUE)
setwd(sub_dir)

home_dir <- file.path(scan_dir, "home")
codex_home <- file.path(scan_dir, "codex_home")
dir.create(file.path(home_dir, ".config", "agents"), recursive = TRUE,
           showWarnings = FALSE)
dir.create(file.path(codex_home, "memories"), recursive = TRUE,
           showWarnings = FALSE)
writeLines(c(
    "# Global Development Preferences",
    "",
    "- Use saber before guessing."
), file.path(home_dir, ".config", "agents", "GLOBAL.md"))
writeLines("saber is meant to be reciprocal",
           file.path(codex_home, "memories", "reciprocal.md"))
memory_dir <- file.path(home_dir, ".claude", "projects",
                        "-home-test-hookpkg", "memory")
dir.create(memory_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c(
    "- [Memory body](memory-body.md) - hookpkg memory index entry"
), file.path(memory_dir, "MEMORY.md"))
writeLines("This body file should not be preloaded.",
           file.path(memory_dir, "memory-body.md"))

output <- system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", script, "claude"),
                  stdout = TRUE, stderr = TRUE,
                  env = c(sprintf("HOME=%s", home_dir),
                          sprintf("CODEX_HOME=%s", codex_home)))

expect_true(length(output) > 0L)
expect_true(identical(trimws(output[[1L]]), "{"))
expect_true(any(grepl('"hookEventName": "SessionStart"', output, fixed = TRUE)))
expect_true(any(grepl('"additionalContext": "# Briefing: hookpkg\\\\n',
                      output)))
expect_true(any(grepl("## Global Preferences\\n\\n# Global Development Preferences",
                      output, fixed = TRUE)))
expect_true(any(grepl("Use saber before guessing.", output, fixed = TRUE)))
expect_false(any(grepl("hookpkg memory index entry", output, fixed = TRUE)))
expect_true(any(grepl("saber is meant to be reciprocal", output,
                      fixed = TRUE)))
expect_false(any(grepl("^# Briefing: hookpkg$", output)))

# Older handlers also use littler, whose arguments live in argv.
littler <- Sys.which("r")
if (nzchar(littler)) {
    littler_output <- system2(littler, c(shQuote(script), "claude"),
                              stdout = TRUE, stderr = TRUE,
                              env = c(sprintf("HOME=%s", home_dir),
                                      sprintf("CODEX_HOME=%s", codex_home)))
    expect_true(any(grepl("Use saber before guessing.", littler_output, fixed = TRUE)))
    expect_true(any(grepl("saber is meant to be reciprocal", littler_output, fixed = TRUE)))
    expect_false(any(grepl("hookpkg memory index entry", littler_output, fixed = TRUE)))
}

codex_output <- system2(file.path(R.home("bin"), "Rscript"), c(script, "codex"),
                        stdout = TRUE, stderr = TRUE,
                        env = c(sprintf("HOME=%s", home_dir),
                                sprintf("CODEX_HOME=%s", codex_home)))

expect_true(any(grepl("## Memory", codex_output, fixed = TRUE)))
expect_true(any(grepl("hookpkg memory index entry", codex_output, fixed = TRUE)))
expect_false(any(grepl("saber is meant to be reciprocal", codex_output,
                       fixed = TRUE)))
expect_false(any(grepl("This body file should not be preloaded.",
                       codex_output, fixed = TRUE)))

corteza_output <- system2(file.path(R.home("bin"), "Rscript"),
                          c(script, "corteza"),
                          stdout = TRUE, stderr = TRUE,
                          env = c(sprintf("HOME=%s", home_dir),
                                  sprintf("CODEX_HOME=%s", codex_home)))

expect_true(any(grepl("hookpkg memory index entry", corteza_output,
                      fixed = TRUE)))
expect_true(any(grepl("saber is meant to be reciprocal", corteza_output,
                      fixed = TRUE)))

# Project instructions: a named agent receives the file it does not autoload.
run_hook <- function(...) {
    system2(file.path(R.home("bin"), "Rscript"), c("--vanilla", script, ...),
            stdout = TRUE, stderr = TRUE,
            env = c(sprintf("HOME=%s", home_dir),
                    sprintf("CODEX_HOME=%s", codex_home)))
}
has_text <- function(output, text) any(grepl(text, output, fixed = TRUE))
claude_md <- file.path(pkg_dir, "CLAUDE.md")
agents_md <- file.path(pkg_dir, "AGENTS.md")

# No project file: nothing to emit.
expect_false(has_text(codex_output, "## CLAUDE.md"))
expect_false(has_text(output, "## AGENTS.md"))

# CLAUDE.md only: Codex and corteza receive it, Claude Code autoloads it.
writeLines("Only the Claude file states this rule.", claude_md)
expect_true(has_text(run_hook("codex"), "## CLAUDE.md"))
expect_true(has_text(run_hook("codex", "--native-shared"),
                     "Only the Claude file states this rule."))
expect_true(has_text(run_hook("corteza"),
                     "Only the Claude file states this rule."))
expect_false(has_text(run_hook("claude"),
                      "Only the Claude file states this rule."))
# Without an agent the native coverage is unknown; behavior is unchanged.
expect_false(has_text(run_hook(), "Only the Claude file states this rule."))

# AGENTS.md as an alias of CLAUDE.md: both agents already have the text.
if (suppressWarnings(file.symlink("CLAUDE.md", agents_md))) {
    expect_false(has_text(run_hook("codex"),
                          "Only the Claude file states this rule."))
    expect_false(has_text(run_hook("claude"),
                          "Only the Claude file states this rule."))
    unlink(agents_md)
}

# A separate identical copy is covered natively too.
file.copy(claude_md, agents_md)
expect_false(has_text(run_hook("codex"),
                      "Only the Claude file states this rule."))
unlink(agents_md)

# AGENTS.md only: Claude Code and corteza receive it, Codex autoloads it.
unlink(claude_md)
writeLines("Only the agents file states this rule.", agents_md)
expect_true(has_text(run_hook("claude"), "## AGENTS.md"))
expect_true(has_text(run_hook("claude", "--native-shared"),
                     "Only the agents file states this rule."))
expect_true(has_text(run_hook("corteza"),
                     "Only the agents file states this rule."))
expect_false(has_text(run_hook("codex"),
                      "Only the agents file states this rule."))

unlink(scan_dir, recursive = TRUE)
