## Resubmission

This is a resubmission of saber 0.7.1.

Changes since 0.2.0 (current CRAN version):

- Rebranded as "Context Engineering for R" with updated title and description.
- Added `agent_context()` for assembling agent context from memory and instruction files.
- Added `fn_graph()`, `pkg_graph()`, and `graph_svg()` for interactive SVG call graphs.
- `blast_radius()` gains `include` parameter for scanning roxygen `@examples` and vignettes.
- `briefing()` now uses `message()` instead of `cat()` for CRAN compliance.
- Added `Depends: R (>= 4.4.0)` and removed local `%||%` operator definition.
- Added copyright holder `cornball.ai` to `Authors@R`.

## Test environments

- local Ubuntu 24.04, R 4.5.3
- GitHub Actions (ubuntu-latest, macos-latest) via r-ci

## R CMD check results

0 errors | 0 warnings | 0 notes

## Downstream dependencies

None on CRAN. Internal dependents: cerebelo, cerebro, corteza.
