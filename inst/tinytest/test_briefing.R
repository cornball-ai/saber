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
    result <- briefing("demopkg", scan_dir = scan_dir, briefs_dir = briefs_dir)
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

# --- briefing skips memory when CLAUDECODE is set ---
old_cc <- Sys.getenv("CLAUDECODE")
Sys.setenv(CLAUDECODE = "1")
mem_base <- file.path(scan_dir, ".claude_mem")
mem_dir <- file.path(mem_base, "-home-user-demopkg", "memory")
dir.create(mem_dir, recursive = TRUE, showWarnings = FALSE)
writeLines("- [Test](test.md) - a test memory", file.path(mem_dir, "MEMORY.md"))
printed_cc <- capture.output(
    result_cc <- briefing("demopkg", scan_dir = scan_dir,
                          memory_base = mem_base, briefs_dir = briefs_dir)
)
expect_false(grepl("Memory", result_cc))
if (nchar(old_cc) > 0L) Sys.setenv(CLAUDECODE = old_cc) else Sys.unsetenv("CLAUDECODE")

# --- briefing includes memory when CLAUDECODE is NOT set ---
old_cc2 <- Sys.getenv("CLAUDECODE")
Sys.unsetenv("CLAUDECODE")
printed_mem <- capture.output(
    result_mem <- briefing("demopkg", scan_dir = scan_dir,
                           memory_base = mem_base, briefs_dir = briefs_dir)
)
expect_true(grepl("Memory", result_mem))
expect_true(grepl("test memory", result_mem))
if (nchar(old_cc2) > 0L) Sys.setenv(CLAUDECODE = old_cc2) else Sys.unsetenv("CLAUDECODE")
unlink(mem_base, recursive = TRUE)

# --- briefing handles missing project gracefully ---
result_missing <- briefing("nonexistent", scan_dir = scan_dir,
                           briefs_dir = briefs_dir)
expect_true(is.character(result_missing))
expect_true(grepl("Briefing: nonexistent", result_missing))

# --- Cleanup ---
unlink(scan_dir, recursive = TRUE)
unlink(briefs_dir, recursive = TRUE)
