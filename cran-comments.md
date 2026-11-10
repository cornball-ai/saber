## Submission

This is saber 0.8.0, a feature update to CRAN version 0.7.2, consolidating
the 0.7.2.x development cycle.

Changes since 0.7.2:

- New exports: `context_manifest()`, `context_render()`, `context_audit()`,
  `skill_manifest()`, `skill_read()`, `src_symbols()`,
  `default_src_exclude()`, `heartbeat()`, `git_commit_count_since()`, and
  `git_log_since()`.
- `blast_radius()` gains `include = "src"`.
- `agent_context()` now merges project 'CLAUDE.md' and 'AGENTS.md' when both
  exist instead of returning one of them.
- No exported function was removed or renamed, and no existing signature
  changed. Depends and Imports are unchanged.

`src_symbols()` uses the suggested package 'bonsaisitter' (on CRAN) and
loads a tree-sitter grammar package per language when one is installed. Of
those, 'treesitter.c' is on CRAN; the others are optional, are not declared
in DESCRIPTION, and are looked up with `requireNamespace()` at run time. The
function stops with an informative error when a grammar is absent, and its
example and tests skip in that case.

Examples and tests write only under `tempdir()`. The test runner also
redirects `R_USER_CACHE_DIR`, `R_USER_DATA_DIR`, and `R_USER_CONFIG_DIR` to
temporary paths.

## Test environments

- local Ubuntu 24.04, R 4.6.1
- win-builder, R-devel and R-release

## R CMD check results

0 errors | 0 warnings | 0 notes (local Ubuntu, R 4.6.1,
`--as-cran --run-donttest`).

## Downstream dependencies

CRAN reverse dependencies: corteza (Imports) and pensar. The CRAN source
tarballs of corteza 0.7.1 and pensar 0.7.0 both pass R CMD check (Status: OK)
against this saber 0.8.0 build.
