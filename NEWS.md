# saber 0.7.1

## Changes

- Rebranded package as "Context Engineering for R".
- `briefing()` now emits output via `message()` instead of `cat()` for CRAN compliance.
- `agent_context()` examples use `\donttest{}` instead of `\dontrun{}`.
- Added `Depends: R (>= 4.4.0)` and removed local `%||%` definition (now in base R).
- Added copyright holder `person("cornball.ai", role = "cph")` to `Authors@R`.

# saber 0.7.0

## New features

- `agent_context()` assembles agent context from memory, instructions, and identity files.
- `fn_graph()`, `pkg_graph()`, and `graph_svg()` render interactive SVG call graphs.
- `blast_radius()` gains `include` parameter for scanning `@examples` and vignettes.

## Improvements

- Expanded "AST" acronym in DESCRIPTION per CRAN reviewer feedback.
- `briefing()` gains `agent` parameter for multi-agent support.
- Session-start hook script accepts agent name as CLI argument.
