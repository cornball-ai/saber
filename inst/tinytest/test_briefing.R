# Tests for briefing()

# --- Setup ---
scan_dir <- file.path(tempdir(), "test_briefing")
briefs_dir <- file.path(tempdir(), "test_briefs")
dir.create(scan_dir, showWarnings = FALSE)

# Create a project with DESCRIPTION
pkg_dir <- file.path(scan_dir, "demopkg")
dir.create(pkg_dir, showWarnings = FALSE)
writeLines(c(
    "Package: demopkg",
    "Title: Demo Package",
    "Version: 0.1.0",
    "Imports: stats"
), file.path(pkg_dir, "DESCRIPTION"))

# Create a git repo with a commit
system2("git", c("-C", pkg_dir, "init", "-q"), stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "config", "user.email", "test@test.com"),
        stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "config", "user.name", "Test"),
        stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "add", "-A"), stdout = FALSE, stderr = FALSE)
system2("git", c("-C", pkg_dir, "commit", "-q", "-m", "init"),
        stdout = FALSE, stderr = FALSE)

# --- briefing() returns invisible character, prints to stdout ---
printed <- capture.output(
    result <- briefing("demopkg", scan_dir = scan_dir, briefs_dir = briefs_dir,
                       memory_base = tempdir())
)
expect_true(is.character(result))
expect_true(grepl("Briefing: demopkg", result))
expect_true(any(grepl("Briefing: demopkg", printed)))

# --- briefing includes DESCRIPTION metadata ---
expect_true(grepl("Demo Package", result))
expect_true(grepl("0.1.0", result))

# --- briefing includes git log ---
expect_true(grepl("Recent commits", result))
expect_true(grepl("init", result))

# --- briefing writes to file ---
outfile <- file.path(briefs_dir, "demopkg.md")
expect_true(file.exists(outfile))

# --- briefing handles missing project gracefully ---
result_missing <- briefing("nonexistent", scan_dir = scan_dir,
                           briefs_dir = briefs_dir, memory_base = tempdir())
expect_true(is.character(result_missing))
expect_true(grepl("Briefing: nonexistent", result_missing))

# --- memory section ---
mem_dir <- file.path(tempdir(), "test_memory", "-home-user-demopkg", "memory")
dir.create(mem_dir, recursive = TRUE, showWarnings = FALSE)
writeLines(c("# Memory", "- something important"), file.path(mem_dir, "MEMORY.md"))

result_mem <- briefing("demopkg", scan_dir = scan_dir, briefs_dir = briefs_dir,
                       memory_base = file.path(tempdir(), "test_memory"))
expect_true(grepl("something important", result_mem))

# --- Cleanup ---
unlink(scan_dir, recursive = TRUE)
unlink(briefs_dir, recursive = TRUE)
unlink(file.path(tempdir(), "test_memory"), recursive = TRUE)
