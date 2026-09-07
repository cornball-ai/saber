---
name: saber
description: Inspect R package APIs, symbols, downstream impact, and context provenance with saber.
---

See [NOTICE.md](NOTICE.md) for the original skill's license notice.

# saber: Code Analysis and Project Context

Choose the operation relevant to the task; do not run every example or load
personal context as part of an ordinary API inspection.

Examples use `Rscript -e` for portability. On *nix, [littler](https://eddelbuettel.github.io/littler/) (`r`) is faster but does not auto-print return values, so wrap with `print()` or use `r -p -e`. See [tinyverse development toolchain](https://cornball.ai/posts/tinyverse-development-toolchain/).

## Before Modifying Any R Package

Check the API first:

```bash
Rscript -e 'saber::pkg_exports("packagename")'
Rscript -e 'saber::pkg_help("function_name", "packagename")'
```

## Before Changing Any Function

Run `blast_radius` FIRST to find every caller:

```bash
Rscript -e 'saber::blast_radius("function_name", project = ".")'
```

This scans the selected project and discoverable downstream projects. Review
positional callers and external compatibility before changing a signature.

**`blast_radius()` is mandatory before renaming, moving, or changing the
signature of any exported function.**

## Project Context

```bash
# Generate a project briefing (metadata, dependents, git log)
Rscript -e 'saber::briefing("projectname")'

# Discover all R packages under ~/
Rscript -e 'saber::projects()'

# Find what depends on a package
Rscript -e 'saber::find_downstream("packagename")'
```

## Agent Context

```bash
# Assemble project + memory + identity files for an agent
Rscript -e 'cat(saber::agent_context(agent = "claude"))'
Rscript -e 'cat(saber::agent_context(agent = "codex"))'
```

`agent_context()` loads project instructions (AGENTS.md / CLAUDE.md), memory,
global preferences, and agent identity files. It skips files the target agent
already autoloads.

## Package skill discovery

`skill_manifest()` discovers package-owned skills from installed libraries
and explicitly supplied checkouts, plus named personal roots. Inspect its
selected metadata and diagnostics; it does not register skills or tools.
These APIs are new in saber 0.7.2.5; check the loaded exports before using them
with an older installation or arrange an isolated development build.
Use `skill_read(manifest, id, resource)` for exact instruction/reference text.
Do not bypass a drift error by reading an unverified replacement path.

## Code Analysis

```bash
# Full symbol index: all function defs and calls
Rscript -e 'str(saber::symbols("."))'

# Just definitions
Rscript -e 'saber::symbols(".")$defs'

# Just call relationships
Rscript -e 'saber::symbols(".")$calls'
```

## Call Graphs

```bash
# Internal function call graph for a project (writes SVG)
Rscript -e 'writeLines(saber::fn_graph("."), "callgraph.svg")'

# Package dependency graph
Rscript -e 'writeLines(saber::pkg_graph(), "deps.svg")'
```

Force-directed SVG via base R Fruchterman-Reingold. No JavaScript.

## Package Introspection

```bash
Rscript -e 'saber::pkg_exports("packagename")'
Rscript -e 'saber::pkg_internals("packagename")'
Rscript -e 'saber::pkg_help("function_name", "packagename")'
```

## Function Reference

| Function | Purpose |
|----------|---------|
| `agent_context(agent, ...)` | Assemble memory, identity, instructions for an agent |
| `briefing(project)` | Project context as markdown (metadata, dependents, git log) |
| `symbols(project_dir)` | AST symbol index (defs + calls) |
| `blast_radius(fn, project)` | Find all callers across projects |
| `fn_graph(project_dir)` | Internal function call graph as SVG |
| `pkg_graph(scan_dir)` | Package dependency graph as SVG |
| `graph_svg(nodes, edges)` | Force-directed graph renderer |
| `find_downstream(package)` | Projects that depend on a package |
| `projects(scan_dir)` | Discover R packages and metadata |
| `pkg_exports(package)` | Exported functions with signatures |
| `pkg_internals(package)` | Internal functions with signatures |
| `pkg_help(topic, package)` | Help docs as markdown |
| `default_exclude()` | Directories skipped when scanning |

## blast_radius Output

Returns a data frame: `caller`, `project`, `file`, `line`, `source`. One row
per call site. An empty result means no matches in the scanned scope, not proof
that external callers do not exist. Pass
`include = c("r", "examples", "vignettes")` to also flag references in
roxygen `@examples` blocks and vignette code chunks.
