# CLAUDE.md

## What this is

saber ("to know") is the AST and code analysis package in the llamaR agent toolchain. It parses R source into structured symbol indices, traces function callers across projects, and provides package introspection. Zero dependencies.

You (Claude Code) are the primary consumer. Troy is the editor-of-last-resort.

## Sister packages

- **pensar** (cornball-ai/pensar): concept graph / ontology (depends on yaml)
- **informR** (cornball-ai/informR): project briefings, heartbeat, feature hubs (depends on pensar)

## Design philosophy

- Base R only. No tidyverse. No pipes. Zero dependencies.
- CRAN-viable.
- Apache-2.0 license.

## Cache layout

```
~/.cache/R/saber/
  symbols/   — per-project RDS caches from symbols()
```

saber never writes outside this directory.

## Core functions

### Code analysis

| Function | Purpose |
|---|---|
| `symbols(project_dir)` | AST symbol index: function defs and calls via `getParseData()` |
| `blast_radius(fn, project)` | Find all callers of a function across projects |

### Package introspection

| Function | Purpose |
|---|---|
| `pkg_exports(package)` | List exported functions with argument signatures |
| `pkg_internals(package)` | List internal (non-exported) functions |
| `pkg_help(topic, package)` | Get help topic as markdown |

## How you use this package

```r
# Symbol index for a project
saber::symbols("~/myproject")

# Who calls this function?
saber::blast_radius("my_function", project = "~/myproject")

# What does a package export?
saber::pkg_exports("dplyr")

# Read help as markdown
saber::pkg_help("mutate", "dplyr")
```

## File structure

```
R/
  symbols.R  — symbols(), AST symbol index via getParseData()
  blast.R    — blast_radius(), cross-project caller tracing
  pkg.R      — pkg_exports(), pkg_internals(), pkg_help()
  utils.R    — file_hash(), parse_dcf_list()
inst/
  tinytest/  — tests
man/         — tinyrox
DESCRIPTION
NAMESPACE
```

## How blast_radius works

`blast_radius()` finds all callers of a function, both within a project and across downstream projects:

1. Builds the symbol index for the target project
2. Finds internal callers from the symbol index
3. Scans `~/` for projects with DESCRIPTION files that declare a dependency (Depends/Imports/LinkingTo) on the target package
4. Builds symbol indices for downstream projects and finds callers there

No ontology needed. Direct DESCRIPTION file scanning via `read.dcf()`.

## Testing

- tinytest, 37 tests
- Tests use temp directories, not real projects

## Things you should NOT do

- Do not add dependencies without asking Troy
- Do not use tidyverse functions or pipes

## Things you SHOULD do

- Keep functions short. If a function is over 80 lines, split it.
- Use `saber::pkg_exports()` and `saber::pkg_help()` to understand packages before modifying code.
