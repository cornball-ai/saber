# basalt

A live project ontology and code intelligence layer for R, built on base R.

basalt gives LLM coding agents (and humans) a structured understanding of how
projects relate to each other, what packages export, and where code changes
will ripple. It parses markdown vaults into a typed knowledge graph, indexes
R source code via AST analysis, and generates context briefings — all without
leaving R.

## Install

```r
remotes::install_github("cornball-ai/basalt")
```

## What it does

**Ontology** — Markdown files with YAML frontmatter and
[Dataview-style](https://blacksmithgu.github.io/obsidian-dataview/) typed
links (`is_a::`, `uses::`, `part_of::`) become a queryable graph stored as
human-readable TSV files. Projects are auto-registered as terms. R package dependencies from
DESCRIPTION files generate `uses` relations automatically.

**Package introspection** — `pkg_exports()`, `pkg_internals()`, and
`pkg_help()` let an LLM inspect any installed R package's API and
documentation as markdown, without external tools.

**Code analysis** — `symbols()` parses `R/*.R` files via `getParseData()` to
build a function definition and call-graph index. `blast_radius()` traces
callers of a function across the current project and all downstream projects
that depend on it.

**Feature hubs** — Markdown files mapping concepts to code locations using
`[[project::function]]` wikilinks, stored in `~/.cache/basalt/hubs/`.

**Context briefings** — `briefing()` assembles ontology identity, sibling
projects, Claude Code memory, and recent git activity into a single markdown
file. `heartbeat()` gives a weekly cross-project summary.

## Quick start

```r
library(basalt)

# Bootstrap: scan ~/projects, build unified ontology
startup()

# Query relationships
query("whisper", "is_a", "ancestors", vault_path = "~/.cache/basalt/vault")
query("torch", "uses", "descendants", vault_path = "~/.cache/basalt/vault")

# Inspect a package
pkg_exports("basalt")
pkg_help("query", "basalt")

# Code analysis
str(symbols("~/basalt"))
blast_radius("load_index", project = "basalt")

# Context
briefing("whisper")
heartbeat()
```

## Inspiration

basalt draws on a few traditions:

- **[Obsidian](https://obsidian.md/)** — The vault-of-markdown-files model
  and `[[wikilink]]` conventions. Obsidian showed that plain text files with
  lightweight linking are a viable knowledge base. basalt borrows the
  frontmatter + typed links pattern (via Dataview-style inline fields) as
  its source of truth.

- **[OBO (Open Biological Ontologies)](http://www.obofoundry.org/)** — The
  formal ontology tooling that the bioinformatics community has maintained
  for decades. basalt's `is_a` / `part_of` relation types, term promotion
  with stable IDs, and OBO format export all come from this lineage.

- **[Context+](https://github.com/ForLoopCodes/contextplus)** — An MCP
  server that combines AST parsing, spectral clustering, and Obsidian-style
  linking to give AI agents structural understanding of large codebases.
  basalt's feature hubs and blast radius analysis are directly inspired by
  Context+'s `get_feature_hub` and `get_blast_radius` tools.

- **[btw](https://github.com/jumpsetgo/btw)** /
  **[fyi](https://github.com/cornball-ai/fyi)** — Tools that make R package
  APIs legible to LLMs. btw pioneered the idea of dumping package exports
  and help pages as structured text for AI consumption. fyi removed the
  need for an MCP server, added internal function introspection, and
  converted Rd to markdown. basalt's `pkg_exports()`, `pkg_internals()`,
  and `pkg_help()` are a direct fold-in of fyi.

- **Base R** — R has shipped `getParseData()`, `tools::Rd_db()`,
  `tools::parse_Rd()`, and `read.dcf()` for decades. basalt's code analysis,
  package introspection, and DESCRIPTION parsing all use these built-in
  facilities directly — no compiled dependencies, no tree-sitter, no
  embedding models. The tinyverse philosophy: if base R already does it,
  use base R.

## License

Apache-2.0
