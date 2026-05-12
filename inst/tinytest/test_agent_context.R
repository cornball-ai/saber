# Tests for agent_context()

# --- Setup ---
root <- file.path(tempdir(), "test_agent_context")
unlink(root, recursive = TRUE)
dir.create(root, recursive = TRUE, showWarnings = FALSE)

project_dir <- file.path(root, "demopkg")
dir.create(project_dir, recursive = TRUE, showWarnings = FALSE)

workspace_dir <- file.path(root, "workspace")
dir.create(workspace_dir, recursive = TRUE, showWarnings = FALSE)

mem_base <- file.path(root, "claude_mem")
mem_proj_dir <- file.path(mem_base, "-home-user-demopkg", "memory")
dir.create(mem_proj_dir, recursive = TRUE, showWarnings = FALSE)

codex_home <- file.path(root, "codex_home")
codex_mem_dir <- file.path(codex_home, "memories")
dir.create(codex_mem_dir, recursive = TRUE, showWarnings = FALSE)

# Fake claude global path (points to nonexistent file by default).
# Use this in all tests to avoid leaking the real ~/.claude/CLAUDE.md.
fake_claude_global <- file.path(root, "fake_home_claude.md")

# Helper that injects the test fixtures
ac <- function(agent, workspace = workspace_dir, ...) {
    old_codex_home <- Sys.getenv("CODEX_HOME", unset = NA_character_)
    Sys.setenv(CODEX_HOME = codex_home)
    on.exit({
        if (is.na(old_codex_home)) {
            Sys.unsetenv("CODEX_HOME")
        } else {
            Sys.setenv(CODEX_HOME = old_codex_home)
        }
    }, add = TRUE)

    saber::agent_context(agent = agent,
                         project_dir = project_dir,
                         workspace_dir = workspace,
                         memory_base = mem_base,
                         claude_global_path = fake_claude_global,
                         ...)
}

write_lines_to <- function(path, lines) {
    writeLines(lines, path)
}

# --- Empty case: no files at all ---
expect_equal(ac("corteza"), "")

# --- AGENTS.md only, codex agent (codex autoloads it -> skipped) ---
write_lines_to(file.path(project_dir, "AGENTS.md"), "Project rules.")
result <- ac("codex")
expect_false(grepl("AGENTS.md", result))
expect_false(grepl("Project rules", result))

# --- AGENTS.md only, claude agent (claude doesn't autoload AGENTS.md) ---
result <- ac("claude")
expect_true(grepl("AGENTS.md", result))
expect_true(grepl("Project rules", result))

# --- CLAUDE.md only, claude agent (autoloaded -> skipped) ---
file.remove(file.path(project_dir, "AGENTS.md"))
write_lines_to(file.path(project_dir, "CLAUDE.md"), "Claude project rules.")
result <- ac("claude")
expect_false(grepl("Claude project rules", result))

# --- CLAUDE.md only, codex agent (loads it as fallback) ---
result <- ac("codex")
expect_true(grepl("CLAUDE.md", result))
expect_true(grepl("Claude project rules", result))

# --- Both files exist, corteza prefers CLAUDE.md ---
write_lines_to(file.path(project_dir, "AGENTS.md"), "Agents version.")
result <- ac("corteza")
expect_true(grepl("Claude project rules", result))
expect_false(grepl("Agents version", result))

# --- Memory loading ---
write_lines_to(file.path(mem_proj_dir, "MEMORY.md"),
               c("- [Test](t.md) - a test memory"))
write_lines_to(file.path(codex_mem_dir, "reciprocal.md"),
               "saber is meant to be reciprocal")
result <- ac("corteza")
expect_true(grepl("## Memory", result))
expect_true(grepl("test memory", result))
expect_true(grepl("## Codex Memories", result))
expect_true(grepl("saber is meant to be reciprocal", result))

# --- Claude memory skipped for claude by default, Codex memory is included ---
result <- ac("claude")
expect_false(grepl("## Memory", result))
expect_true(grepl("saber is meant to be reciprocal", result))

# --- Codex memory skipped for codex by default, Claude memory is included ---
result <- ac("codex")
expect_true(grepl("test memory", result))
expect_false(grepl("saber is meant to be reciprocal", result))

# --- Corteza receives both memory systems ---
result <- ac("corteza")
expect_true(grepl("test memory", result))
expect_true(grepl("saber is meant to be reciprocal", result))

# --- Memory force-included for claude includes both memory systems ---
result <- ac("claude", include_memory = TRUE)
expect_true(grepl("## Memory", result))
expect_true(grepl("saber is meant to be reciprocal", result))

# --- Memory can be disabled for all memory systems ---
result <- ac("corteza", include_memory = FALSE)
expect_false(grepl("test memory", result))
expect_false(grepl("saber is meant to be reciprocal", result))

# --- Legacy llamar identifier remains a corteza alias ---
result <- ac("llamar")
expect_true(grepl("test memory", result))
expect_true(grepl("saber is meant to be reciprocal", result))

# --- SOUL.md and USER.md from workspace ---
write_lines_to(file.path(workspace_dir, "SOUL.md"), "I am the soul.")
write_lines_to(file.path(workspace_dir, "USER.md"), "User preferences here.")
result <- ac("corteza")
expect_true(grepl("SOUL.md", result))
expect_true(grepl("I am the soul", result))

# --- USER.md loads for claude when claude_global_path doesn't exist ---
result <- ac("claude")
expect_true(grepl("User preferences here", result))

# --- claude_global_path file is loaded for codex/corteza ---
write_lines_to(fake_claude_global, "Fake claude global content.")
result <- ac("corteza")
expect_true(grepl("Fake claude global content", result))
# When claude global exists, USER.md is the fallback (not loaded)
expect_false(grepl("User preferences here", result))

# --- claude_global_path is skipped for claude (autoloaded) ---
result <- ac("claude")
expect_false(grepl("Fake claude global content", result))
# But USER.md still loads for claude
expect_true(grepl("User preferences here", result))

# Reset for remaining tests
file.remove(fake_claude_global)

# --- include_soul = FALSE skips SOUL.md ---
result <- ac("corteza", include_soul = FALSE)
expect_false(grepl("I am the soul", result))

# --- workspace_dir = NULL skips SOUL.md and USER.md ---
result <- ac("corteza", workspace = NULL)
expect_false(grepl("SOUL", result))
expect_false(grepl("USER", result))

# --- NULL agent loads everything ---
result <- ac(NULL)
expect_true(grepl("## Memory", result))
expect_true(grepl("Claude project rules", result))
expect_true(grepl("I am the soul", result))

# --- include_project = FALSE skips even when files exist ---
result <- ac("corteza", include_project = FALSE)
expect_false(grepl("Claude project rules", result))

# --- Symlink dedup: AGENTS.md symlink to CLAUDE.md, claude agent skips both ---
file.remove(file.path(project_dir, "AGENTS.md"))
file.symlink("CLAUDE.md", file.path(project_dir, "AGENTS.md"))
result <- ac("claude")
# AGENTS.md is a symlink to CLAUDE.md, and claude autoloads CLAUDE.md,
# so AGENTS.md should also be skipped (same canonical file)
expect_false(grepl("Claude project rules", result))

# --- Cleanup ---
unlink(root, recursive = TRUE)
