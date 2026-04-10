# Tests for session-start hook script

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
dir.create(file.path(home_dir, ".config", "agents"), recursive = TRUE,
           showWarnings = FALSE)
writeLines(c(
    "# Global Development Preferences",
    "",
    "- Use saber before guessing."
), file.path(home_dir, ".config", "agents", "GLOBAL.md"))

output <- system2(file.path(R.home("bin"), "Rscript"), c(script, "claude"),
                  stdout = TRUE, stderr = TRUE,
                  env = c(sprintf("HOME=%s", home_dir)))

expect_true(length(output) > 0L)
expect_true(identical(trimws(output[[1L]]), "{"))
expect_true(any(grepl('"hookEventName": "SessionStart"', output, fixed = TRUE)))
expect_true(any(grepl('"additionalContext": "# Briefing: hookpkg\\\\n',
                      output)))
expect_true(any(grepl("## Global Preferences\\n\\n# Global Development Preferences",
                      output, fixed = TRUE)))
expect_true(any(grepl("Use saber before guessing.", output, fixed = TRUE)))
expect_false(any(grepl("^# Briefing: hookpkg$", output)))

unlink(scan_dir, recursive = TRUE)
