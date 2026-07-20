# heartbeat() scans immediate subdirectories of scan_dir for git repos
# with commits inside the lookback window.

git_ok <- nzchar(Sys.which("git"))

if (git_ok) {
    root <- file.path(tempdir(), "hbroot")
    briefs <- file.path(tempdir(), "hbbriefs")
    dir.create(root, showWarnings = FALSE)

    # An active repo: one commit right now
    active <- file.path(root, "activepkg")
    dir.create(active, showWarnings = FALSE)
    writeLines("hello", file.path(active, "a.txt"))
    system2("git", c("-C", active, "init", "-q"))
    system2("git", c("-C", active, "add", "a.txt"))
    system2("git", c("-C", active,
                     "-c", "user.name=t", "-c", "user.email=t@example.com",
                     "commit", "-q", "-m", shQuote("add a")))

    # A git repo with no commits at all
    quiet <- file.path(root, "quietpkg")
    dir.create(quiet, showWarnings = FALSE)
    system2("git", c("-C", quiet, "init", "-q"))

    # A plain directory that is not a repo
    dir.create(file.path(root, "plaindir"), showWarnings = FALSE)

    text <- suppressMessages(heartbeat(days = 7, scan_dir = root,
                                       briefs_dir = briefs))

    expect_true(grepl("activepkg (1 commit)", text, fixed = TRUE))
    expect_true(grepl("add a", text, fixed = TRUE))
    expect_false(grepl("quietpkg", text, fixed = TRUE))
    expect_false(grepl("plaindir", text, fixed = TRUE))
    expect_true(file.exists(file.path(briefs, "_heartbeat.md")))

    # Excluded directory basenames are skipped
    text2 <- suppressMessages(heartbeat(days = 7, scan_dir = root,
                                        exclude = "activepkg",
                                        briefs_dir = briefs))
    expect_true(grepl("No commits in the window", text2, fixed = TRUE))
}

# Exported git helpers: count and log primitives behind heartbeat()
if (git_ok) {
    expect_identical(git_commit_count_since(active, Sys.Date() - 7), 1L)
    expect_identical(git_commit_count_since(file.path(root, "plaindir"),
                                            Sys.Date() - 7), 0L)

    log1 <- git_log_since(active, Sys.Date() - 7)
    expect_identical(length(log1), 1L)
    expect_true(grepl("add a", log1, fixed = TRUE))

    # NULL since_date means unbounded
    expect_identical(git_log_since(active, NULL), log1)

    # iso format: tab-separated ISO timestamp, short hash, subject
    iso <- git_log_since(active, format = "iso")
    expect_identical(length(iso), 1L)
    parts <- strsplit(iso, "\t", fixed = TRUE)[[1L]]
    expect_identical(length(parts), 3L)
    expect_true(grepl("^[0-9]{4}-[0-9]{2}-[0-9]{2} ", parts[1L]))
    expect_identical(parts[3L], "add a")

    # Non-repos and empty repos return empty logs
    expect_identical(git_log_since(file.path(root, "plaindir")), character(0))
    expect_identical(git_log_since(quiet), character(0))
}
