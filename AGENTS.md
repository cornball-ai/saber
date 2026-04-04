# Repository Guidelines

## What This Is

saber is a zero-dependency R package for code analysis and project context. It parses R source into symbol indices, traces callers across projects, discovers package metadata, generates project briefings, and inspects installed packages.

## Working Rules

- Base R only. No tidyverse. No pipes.
- Keep the package CRAN-viable.
- Do not add dependencies without asking the maintainer.
- Keep functions short and easy to scan. Split them once they stop being obvious.

## Use saber Before Guessing

- Use `saber::pkg_exports()` and `saber::pkg_help()` before changing code that depends on another package.
- Use `saber::symbols()` when you need the local call graph.
- Use `saber::blast_radius()` before renaming, moving, or changing the signature of any exported function.
- Use `saber::briefing()` when you need project-level context at the start of a session.

## Repo Map

- `R/` contains exported functions and internal helpers.
- `inst/tinytest/` contains tests.
- `inst/scripts/` contains session-start and analysis scripts.
- `man/`, `DESCRIPTION`, and `NAMESPACE` hold package metadata.

## Style

- Prefer snake_case names.
- Keep cache writes inside `tools::R_user_dir("saber", "cache")`.
- Add small, targeted comments only when the code is not self-explanatory.
