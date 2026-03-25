# saber

Code analysis and project context for R. Zero dependencies.

saber ("to know") parses R source into structured symbol indices, traces function callers across projects, discovers dependency graphs, generates project briefings, and cracks open installed packages for introspection. Built for AI coding agents that need to understand R code without guessing.

## Install

```r
remotes::install_github("cornball-ai/saber")
```

## What it does

**9 exported functions.** That's the whole API.

| Function | What it does |
|---|---|
| `symbols()` | Parse R source files into function defs and calls via `getParseData()` |
| `blast_radius()` | Find every caller of a function, across projects |
| `find_downstream()` | Find all projects that depend on a given package |
| `projects()` | Discover R package projects and their metadata |
| `briefing()` | Generate a project context briefing (metadata, dependents, memory, git log) |
| `pkg_exports()` | List exported functions with argument signatures |
| `pkg_internals()` | List internal (non-exported) functions |
| `pkg_help()` | Pull help documentation as markdown |
| `default_exclude()` | Default directories to skip when scanning |

## Examples

Index all function definitions and calls in a project:

```r
syms <- saber::symbols("~/myproject")
syms$defs  # data.frame: name, file, line, exported
syms$calls # data.frame: caller, callee, file, line
```

Find who calls a function (and where the damage lands if you change it):

```r
saber::blast_radius("my_function", project = "~/myproject")
#>   caller      project      file         line
#>   do_thing    myproject    main.R         42
#>   run_batch   downstream   pipeline.R     17
```

Discover projects and their dependencies:

```r
saber::projects()
#>   package   title                  version  path            depends  imports
#>   saber     Code Analysis for R    0.2.0    /home/troy/saber        ...

saber::find_downstream("saber")
#>   [1] "cerebelo" "informR"
```

Generate a project briefing for an AI agent:

```r
cat(saber::briefing("saber"))
#> # Briefing: saber
#> _Generated 2026-03-25 00:30_
#>
#> ## Package
#> - **Name**: saber
#> - **Title**: Code Analysis and Project Context for R
#> - **Version**: 0.2.0
#>
#> ## Recent commits
#> - 7983478 Add r-ci GitHub Actions workflow
#> - ...
```

Inspect any installed package without opening a browser:

```r
saber::pkg_exports("saber")
saber::pkg_help("symbols", "saber")
```

## How it works

`symbols()` runs `getParseData()` on every `R/*.R` file in a project, extracts function definitions and call sites, and caches the results as RDS in `~/.cache/R/saber/symbols/`. Cache invalidates on file content changes (MD5).

`blast_radius()` builds on top of `symbols()`. It finds internal callers, then scans `~/` for any project whose DESCRIPTION declares a dependency on the target package. Traces the call graph across all of them.

`projects()` scans for directories containing DESCRIPTION files and reads their metadata. `find_downstream()` does the same scan but filters to projects that depend on a specific package.

`briefing()` assembles project context from DESCRIPTION metadata, downstream dependents, Claude Code memory files, and recent git commits. Writes to `~/.cache/R/saber/briefs/` so both the agent and user see the same context.

## License

Apache-2.0
