# saber

AST symbol index and code analysis for R projects. Zero dependencies.

saber ("to know") parses R source into structured symbol indices, traces function callers across projects, and cracks open installed packages for introspection. Built for AI coding agents that need to understand R code without guessing.

Part of [cerebro](https://github.com/cornball-ai/cerebro), the AI agent toolchain for R.

## Install

```r
remotes::install_github("cornball-ai/saber")
```

## What it does

**5 exported functions.** That's the whole API.

| Function | What it does |
|---|---|
| `symbols()` | Parse R source files into function defs and calls via `getParseData()` |
| `blast_radius()` | Find every caller of a function, across projects |
| `pkg_exports()` | List exported functions with argument signatures |
| `pkg_internals()` | List internal (non-exported) functions |
| `pkg_help()` | Pull help documentation as markdown |

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

Inspect any installed package without opening a browser:

```r
saber::pkg_exports("saber")
#>   name           args
#>   blast_radius   fn, project, scan_dir, cache_dir
#>   pkg_exports    package, pattern
#>   pkg_help       topic, package, format
#>   pkg_internals  package, pattern
#>   symbols        project_dir, cache_dir

saber::pkg_help("symbols", "saber")
```

## How it works

`symbols()` runs `getParseData()` on every `R/*.R` file in a project, extracts function definitions and call sites, and caches the results as RDS in `~/.cache/R/saber/symbols/`. Cache invalidates on file content changes (MD5).

`blast_radius()` builds on top of `symbols()`. It finds internal callers, then scans `~/` for any project whose DESCRIPTION declares a dependency on the target package. Traces the call graph across all of them.

## Sister packages

| Package | Purpose |
|---|---|
| [pensar](https://github.com/cornball-ai/pensar) | Concept graph and ontology |
| [informR](https://github.com/cornball-ai/informR) | Project briefings and feature hubs |
| [mirar](https://github.com/cornball-ai/mirar) | Runtime inspection of live R sessions |
| [llamaR](https://github.com/cornball-ai/llamaR) | Agent runtime and chat loop |

## License

Apache-2.0
