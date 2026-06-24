## Submission

This is saber 0.7.2, a maintenance update to CRAN version 0.7.1,
consolidating the 0.7.1.x development cycle.

Changes since 0.7.1:

- `fn_graph()` gains a `cache_dir` argument so its example and tests write
  under `tempdir()` instead of the user cache (#32).
- `briefing_git()` no longer emits a `system2()` "status 128" warning when
  run against a non-repository (#33).
- The SessionStart hook only sources a local package's `R/` when that package
  is saber itself (#31).

## Test environments

- local Ubuntu 24.04, R 4.6.0
- win-builder, R-devel

## R CMD check results

0 errors | 0 warnings | 0 notes (local Ubuntu, R 4.6.0).

## Downstream dependencies

CRAN reverse dependency: corteza (Imports). corteza 0.6.9 R CMD checks cleanly
against this saber 0.7.2 build (tests, examples, and vignettes all OK). The
only warning is the incoming-feasibility "version already exists" artifact from
re-checking the published tarball, which is unrelated to saber.
