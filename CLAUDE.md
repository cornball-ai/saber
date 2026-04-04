# CLAUDE.md

## What this is

saber ("to know") is a code analysis and project context package for R. It parses R source into structured symbol indices, traces function callers across projects, discovers dependency graphs, generates project briefings, and provides package introspection. Zero dependencies.

You (Claude Code) are the primary consumer. The user is the editor-of-last-resort.

## Design philosophy

- Base R only. No tidyverse. No pipes. Zero dependencies.
- CRAN-viable.
- Apache-2.0 license.

## Cache layout

```
~/.cache/R/saber/
  symbols/   — per-project RDS caches from symbols()
  briefs/    — project briefing markdown files from briefing()
```

saber never writes outside this directory (except briefings, which also return their content).

## Core functions

### Code analysis

| Function | Purpose |
|---|---|
| `symbols(project_dir)` | AST symbol index: function defs and calls via `getParseData()` |
| `blast_radius(fn, project)` | Find all callers of a function across projects |

### Project discovery

| Function | Purpose |
|---|---|
| `projects(scan_dir)` | Discover R package projects and their metadata |
| `find_downstream(package)` | Find all projects that depend on a given package |
| `briefing(project)` | Generate project context briefing (metadata, dependents, memory, git log) |

### Package introspection

| Function | Purpose |
|---|---|
| `pkg_exports(package)` | List exported functions with argument signatures |
| `pkg_internals(package)` | List internal (non-exported) functions |
| `pkg_help(topic, package)` | Get help topic as markdown |

## File structure

```
R/
  symbols.R   — symbols(), AST symbol index via getParseData()
  blast.R     — blast_radius(), cross-project caller tracing
  projects.R  — projects(), find_downstream(), project discovery
  briefing.R  — briefing(), project context generation
  pkg.R       — pkg_exports(), pkg_internals(), pkg_help()
  utils.R     — file_hash(), default_exclude()
inst/
  tinytest/   — tests
man/          — tinyrox
DESCRIPTION
NAMESPACE
```

## Things you should NOT do

- Do not add dependencies without asking the user
- Do not use tidyverse functions or pipes

## Things you SHOULD do

- Keep functions short. If a function is over 80 lines, split it.
- Use `saber::pkg_exports()` and `saber::pkg_help()` to understand packages before modifying code.
