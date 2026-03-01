# Tests for briefing.R

library(basalt)

# --- Setup: create a minimal vault with terms and relations ---

vault <- tempfile("vault")
dir.create(vault)

writeLines(c(
  "---",
  "type: term",
  "---",
  "# whisper"
), file.path(vault, "whisper.md"))

index_vault(vault)

# Add terms and relations via add()
add(
  terms = c("stt", "audio", "torch", "cornyverse"),
  relations = data.frame(
    subject = c("whisper", "whisper", "whisper", "whisper"),
    relation_type = c("is_a", "is_a", "part_of", "uses"),
    object = c("stt", "audio", "cornyverse", "torch"),
    stringsAsFactors = FALSE
  ),
  vault_path = vault,
  annotations_dir = NULL
)

# --- Setup: fake memory ---

fake_memory <- tempfile("memory")
mem_dir <- file.path(fake_memory, "-home-fakeuser-whisper", "memory")
dir.create(mem_dir, recursive = TRUE)
writeLines(c(
  "# Whisper Memory",
  "",
  "Mel spectrograms computed in R/audio.R"
), file.path(mem_dir, "MEMORY.md"))

# --- Setup: fake git repo ---

fake_home <- tempfile("home")
dir.create(fake_home)
fake_repo <- file.path(fake_home, "whisper")
dir.create(fake_repo)
# Init a git repo with a commit
system2("git", c("-C", fake_repo, "init", "-q"))
system2("git", c("-C", fake_repo, "config", "user.email", "test@test.com"))
system2("git", c("-C", fake_repo, "config", "user.name", "Test"))
writeLines("test", file.path(fake_repo, "test.txt"))
system2("git", c("-C", fake_repo, "add", "."))
system(sprintf("git -C '%s' commit -q -m 'initial commit'", fake_repo))

# --- Test briefing ---

briefs <- tempfile("briefs")

text <- briefing(
  project = "whisper",
  vault_path = vault,
  briefs_dir = briefs,
  memory_base = fake_memory,
  scan_dir = fake_home
)

# Should return a character string
expect_true(is.character(text))
expect_true(nchar(text) > 0L)

# Should contain ontology info
expect_true(grepl("stt", text))
expect_true(grepl("cornyverse", text))
expect_true(grepl("torch", text))

# Should contain memory
expect_true(grepl("Mel spectrograms", text))

# Should contain git
expect_true(grepl("initial commit", text))

# Should write briefing file
expect_true(file.exists(file.path(briefs, "whisper.md")))

# --- Test with unknown project ---

text2 <- briefing(
  project = "nonexistent",
  vault_path = vault,
  briefs_dir = briefs,
  memory_base = fake_memory,
  scan_dir = fake_home
)

# Should still produce output (just with "not in the ontology" message)
expect_true(is.character(text2))
expect_true(grepl("not in the ontology", text2))

# --- Cleanup ---
unlink(c(vault, fake_memory, fake_home, briefs), recursive = TRUE)
