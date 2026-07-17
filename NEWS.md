# saber 0.7.2.1 (development)

- New `src_symbols()`: C, C++, and Python symbol index for any repository via
  tree-sitter (suggested `bonsaisitter` runtime + a grammar package per
  language: `treesitter.c`, `treesitter.cpp`, `treesitter.python`). Mirrors
  `symbols()` with a `lang` column; `exported` marks definitions visible
  beyond their own file (non-`static` in C/C++, no leading underscore in
  Python). New `default_src_exclude()` lists directories skipped while
  scanning.
- `blast_radius()` gains `include = "src"` to report C/C++/Python callers
  from the target project's sources.

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
