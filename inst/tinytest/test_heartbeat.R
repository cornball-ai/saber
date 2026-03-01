# Tests for heartbeat.R

library(basalt)

# --- Setup: fake project dirs with git repos ---

fake_home <- tempfile("home")
dir.create(fake_home)

# Project with a recent commit
proj1 <- file.path(fake_home, "project_a")
dir.create(proj1)
system2("git", c("-C", proj1, "init", "-q"))
system2("git", c("-C", proj1, "config", "user.email", "test@test.com"))
system2("git", c("-C", proj1, "config", "user.name", "Test"))
writeLines("hello", file.path(proj1, "file.txt"))
system2("git", c("-C", proj1, "add", "."))
system(sprintf("git -C '%s' commit -q -m 'add file'", proj1))

# Project with no git repo
dir.create(file.path(fake_home, "project_b"))

# --- Setup: fake annotations ---

fake_ann <- tempfile("annotations")
dir.create(fake_ann)
writeLines(c(
  "---",
  "source: ont_add",
  "---",
  "## Terms",
  "- alpha"
), file.path(fake_ann, "add-20260228-120000.md"))

# --- Test heartbeat ---

briefs <- tempfile("briefs")

text <- ont_heartbeat(
  scan_dir = fake_home,
  briefs_dir = briefs,
  annotations_dir = fake_ann
)

# Should return character string
expect_true(is.character(text))
expect_true(nchar(text) > 0L)

# Should mention active project
expect_true(grepl("project_a", text))

# Should include recent annotations
expect_true(grepl("add-20260228", text))

# Should write heartbeat file
expect_true(file.exists(file.path(briefs, "_heartbeat.md")))

# --- Test with empty dirs ---

empty_home <- tempfile("empty_home")
dir.create(empty_home)
empty_briefs <- tempfile("empty_briefs")

text2 <- ont_heartbeat(
  scan_dir = empty_home,
  briefs_dir = empty_briefs,
  annotations_dir = NULL
)

# Should still produce output (header only)
expect_true(is.character(text2))
expect_true(grepl("Heartbeat", text2))

# --- Cleanup ---
unlink(c(fake_home, fake_ann, briefs, empty_home, empty_briefs),
       recursive = TRUE)
