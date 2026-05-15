## Submission

This is saber 0.7.1, an update to the current CRAN version 0.3.0.

Changes since 0.3.0:

- Rebranded as "Context Engineering for R" with updated title and description.
- Added `agent_context()` for assembling agent context from memory and instruction files, with reciprocal cross-agent memory loading (Codex receives Claude `MEMORY.md`; Claude and other agents receive Codex memories).
- Added `fn_graph()`, `pkg_graph()`, and `graph_svg()` for interactive SVG call graphs.
- `blast_radius()` gains `include` parameter for scanning roxygen `@examples` and vignettes.
- `briefing()` now emits output via `message()` instead of `cat()` for CRAN compliance.
- `agent_context()` examples use `\donttest{}` instead of `\dontrun{}`.
- Added `Depends: R (>= 4.4.0)` and removed local `%||%` operator definition (now in base R).
- Added copyright holder `cornball.ai` to `Authors@R`.

## Test environments

- local Ubuntu 24.04, R 4.5.3
- GitHub Actions (ubuntu-latest, macos-latest) via r-ci

## R CMD check results

0 errors | 0 warnings | 0 notes

## Downstream dependencies

None on CRAN. Internal dependents: cerebelo, cerebro, corteza.
