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

output <- system2(file.path(R.home("bin"), "Rscript"), c(script, "claude"),
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

unlink(scan_dir, recursive = TRUE)
