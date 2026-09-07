# saber repository guidelines

saber is a zero-dependency R package for context engineering. It assembles
agent context, audits source provenance and cost, traces call blast radius,
builds symbol indices and dependency graphs, and inspects installed packages.

## Working rules

- Base R only. No tidyverse or pipes. Keep the package CRAN-viable.
- Ask before adding dependencies or increasing the minimum R version.
- Keep functions short and obvious; split by responsibility and split functions over 80 lines.
- Preserve the Apache-2.0 license.
- Prefer snake_case.
- Prefer backwards compatibility in saber, given its existing users. Breaking
  changes are acceptable when there is a good reason and a clearly better
  design; explain the benefit, user impact, and migration path. This does not
  require keeping every alias forever or set policy for other packages.
- Claude, Codex, and corteza are equal consumers of the shared context.
- Keep persistent cache writes inside `tools::R_user_dir("saber", "cache")`.
  Use temporary directories for test fixtures and caller-specified paths for
  explicitly requested output.

## Inspect before changing

- Use `saber::pkg_exports()` and `saber::pkg_help()` before relying on another
  package's API. Print returned tables or text explicitly in littler commands.
- Use `saber::symbols()` for the local call graph and `saber::briefing()` for
  project-level context.
- Run `saber::blast_radius()` before renaming, moving, or changing the
  signature of an exported function. Its local results do not prove that
  external callers do not exist.

## Repository map

- `R/`: public functions and internal helpers.
- `inst/tinytest/`: tests; `tests/tinytest.R`: package-check runner.
- `inst/scripts/`: session-start hook and analysis scripts.
- `man/`, `DESCRIPTION`, `NAMESPACE`: generated documentation and metadata.
- R and non-R symbol caches live under the saber cache's `symbols/` directory;
  briefings use its `briefs/` directory by default.

## Current context interfaces

- `agent_context()` remains the legacy character-returning API.
- `context_manifest()` records routing and provenance; `context_render()`
  explicitly returns source text; `context_audit()` and print methods expose
  metadata without source bodies.
- Native coverage must match the consumer's audience. Preserve requested
  paths separately from canonical identity and avoid reinjecting native files.
- `src_symbols()` uses optional tree-sitter support; ordinary R functionality
  must work without it.

## Verification

Use the established tinypkgr/tinyrox/rformat/tinytest toolchain. Test against
the intended build in an isolated library when another session uses the normal
installation. Review generated Rd and NAMESPACE changes and omit unrelated
formatting churn. Never change an active downstream run as part of a package
check or context migration.
