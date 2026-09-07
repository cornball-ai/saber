# saber 0.7.2.4 (development)

- Preserve all existing exported APIs, defaults, legacy consumer aliases,
  shared-file conventions, and existing hook invocations. No dependencies or
  minimum R version changes.
- The existing session-start script accepts an optional trailing
  `--native-shared` flag. It suppresses shared preferences only when the
  native global entrypoint resolves to the same readable file, respecting
  Codex's override file. Without the flag, historical injection is unchanged.
- Fix JSON escaping for all representable control characters in hook output.
- Document portable registration through the installed package, all-event
  SessionStart matching, and native shared-file links. Essential instructions
  should remain available without hooks; Claude Explore/Plan limitations are
  documented rather than treated as supported hook injection.

# saber 0.7.2.3 (development)

- New `context_manifest()`, `context_render()`, and `context_audit()` provide
  explicit source routing, native-file suppression, exact deduplication,
  provenance, and named character/line budgets. Print methods and audit
  results expose metadata without source bodies. Existing `agent_context()`
  and `pkg_help()` behavior is unchanged; no dependencies or R version
  requirements were added.
- Native coverage only suppresses sources when its audience matches the
  current consumer. Source metadata retains `requested_path` alongside
  resolved and canonical paths. Native path aliases are deduplicated by
  canonical identity, preserving the first requested spelling.
- The session-start hook now reads littler's `argv` as well as Rscript's
  command arguments, so explicit consumer names work with either launcher.

# saber 0.7.2.2 (development)

- New exports `git_commit_count_since()` and `git_log_since()`: the git
  count/log primitives behind `heartbeat()`, for downstream tooling that
  composes its own activity reports. `git_log_since()` supports an
  unbounded window (`since_date = NULL`) and an `"iso"` line format.

# saber 0.7.2.1 (development)

- New `src_symbols()`: C, C++, Python, Rust, and JavaScript symbol index for
  any repository via tree-sitter (suggested `bonsaisitter` runtime + a
  grammar package per language: `treesitter.c`, `treesitter.cpp`,
  `treesitter.python`, `treesitter.rust`, `treesitter.javascript`). Mirrors
  `symbols()` with a `lang` column; `exported` marks definitions visible
  beyond their own file (non-`static` in C/C++, no leading underscore in
  Python, `pub` in Rust, `export`-wrapped in JavaScript). New
  `default_src_exclude()` lists directories skipped while scanning: the
  `default_exclude()` opt-outs (`Documents` and friends) plus
  dependency/build trees (`node_modules`, `__pycache__`, `venv`, `build`,
  `dist`, `renv`, `target`); hidden and `*.Rcheck` directories are always
  skipped.
- `blast_radius()` gains `include = "src"` to report C/C++/Python/Rust/JS
  callers from the target project's sources.
- New `heartbeat()`: cross-project git activity summary. Scans every
  repository under `scan_dir`, reports projects with commits in the lookback
  window (busiest first), and writes `briefs/_heartbeat.md`. The one-glance
  complement to `briefing()`.

# saber 0.7.2

Consolidates the 0.7.1.x development cycle.

## Changes

- `fn_graph()` now accepts `cache_dir`, mirroring `blast_radius()` and
  `symbols()`. The default is unchanged. The example and tinytest pass
  `tempdir()` so R CMD check no longer leaves files under
  `tools::R_user_dir("saber", "cache")` (#32).
- `briefing_git()` no longer leaks a `system2()` "had status 128" warning
  when run against a non-repository (e.g. a worktree, an invalid `.git`, or
  a dubious-ownership directory). It now confirms the working tree with
  `git rev-parse` and suppresses the warning, returning empty silently (#33).
- The SessionStart hook only sources a local package's `R/` when that package
  is saber itself, so a same-named function exported by another project on the
  load path is no longer picked up in place of saber's (#31).

# saber 0.7.1

## Changes

- Rebranded package as "Context Engineering for Large Language Model Agents".
- `briefing()` now emits output via `message()` instead of `cat()` for CRAN compliance.
- `agent_context()` examples use `\donttest{}` instead of `\dontrun{}`.
- `agent_context()` and the SessionStart hook now load memory reciprocally:
  Codex receives Claude Code `MEMORY.md`, while Claude Code, Corteza, and
  other non-Codex agents receive Codex memories.
- Codex hook setup docs now use `[features].hooks` instead of deprecated
  `[features].codex_hooks`.
- Added `Depends: R (>= 4.4.0)` and removed local `%||%` definition (now in base R).
- Added copyright holder `person("cornball.ai", role = "cph")` to `Authors@R`.
- Expanded acronyms in DESCRIPTION ("AI", "AST") per CRAN policy.
- Single-quoted file-name references in DESCRIPTION ('AGENTS.md', 'CLAUDE.md').
- Added `?saber` package-level help page.
- README examples switched from `r -e` to `Rscript -e` for portability.
- Fix `blast_radius()` vignette scan crashing on Windows paths (backslashes
  were interpreted as regex backreferences).
- Replace em-dashes in roxygen `@title` lines with colons to keep the
  generated Rd files ASCII-clean.

# saber 0.7.0

## New features

- `agent_context()` assembles agent context from memory, instructions, and identity files.
- `fn_graph()`, `pkg_graph()`, and `graph_svg()` render interactive SVG call graphs.
- `blast_radius()` gains `include` parameter for scanning `@examples` and vignettes.

## Improvements

- Expanded "AST" acronym in DESCRIPTION per CRAN reviewer feedback.
- `briefing()` gains `agent` parameter for multi-agent support.
- Session-start hook script accepts agent name as CLI argument.
