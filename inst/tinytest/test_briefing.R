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

ont_index(vault)

# Add terms and relations directly
db <- file.path(vault, ".ontolite", "index.db")
con <- RSQLite::dbConnect(RSQLite::SQLite(), db)

for (t in c("whisper", "stt", "audio", "torch", "cornyverse")) {
  RSQLite::dbExecute(con,
    "INSERT OR IGNORE INTO terms (id, name, promoted, updated_at)
     VALUES (?, ?, 0, strftime('%Y-%m-%dT%H:%M:%S', 'now'))",
    params = list(t, t))
}

RSQLite::dbExecute(con,
  "INSERT OR IGNORE INTO relations
     (subject_id, relation_type, object_id, confirmed, source)
   VALUES ('whisper', 'is_a', 'stt', 1, 'manual')")
RSQLite::dbExecute(con,
  "INSERT OR IGNORE INTO relations
     (subject_id, relation_type, object_id, confirmed, source)
   VALUES ('whisper', 'is_a', 'audio', 1, 'manual')")
RSQLite::dbExecute(con,
  "INSERT OR IGNORE INTO relations
     (subject_id, relation_type, object_id, confirmed, source)
   VALUES ('whisper', 'part_of', 'cornyverse', 1, 'manual')")
RSQLite::dbExecute(con,
  "INSERT OR IGNORE INTO relations
     (subject_id, relation_type, object_id, confirmed, source)
   VALUES ('whisper', 'uses', 'torch', 1, 'manual')")

RSQLite::dbDisconnect(con)

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

text <- ont_briefing(
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

text2 <- ont_briefing(
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
