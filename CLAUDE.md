# CLAUDE.md

## What this is

A small R package that maintains a live ontology from a markdown vault. You (Claude Code) are the primary consumer. Troy is the editor-of-last-resort.

The vault (markdown files with frontmatter and typed links) is the source of truth. The TSV index is derived. Never edit the index directly — edit the markdown, then rebuild.

This package is new and should evolve rapidly depending on how we end up using it. Don't be afraid to propose big changes depending on what's working.

## Design philosophy

- Base R. No tidyverse. No pipes.
- One real dependency: yaml. Everything else is base R.
- Index stored as TSV files (human-readable, diffable).
- OBO emit is just writeLines(). No serialization library.
- CRAN-viable.
- Apache-2.0 license (consistent with cornyverse core packages).

## How you use this package

Shell into R:

```
r -e 'basalt::query("neural_networks", "is_a", "ancestors", vault_path = "~/.cache/basalt/vault")'
```

Use the query results to build context, pick retrieval targets, expand search terms to descendants, or verify relationships before asserting them in conversation.

## Core functions

### Ontology

| Function | Purpose |
|---|---|
| `index_vault(vault_path)` | Parse markdown files, build/update TSV index |
| `query(term, relation, direction)` | Traverse the typed graph (ancestors, descendants, siblings) |
| `suggest(vault_path)` | Propose typed edges from untyped links. Returns candidates, NOT facts. |
| `promote(term, vault_path)` | Write a stable `id:` into a file's frontmatter |
| `emit_obo(vault_path, outfile)` | Snapshot the current ontology to OBO format |
| `status(vault_path)` | Summary stats: term count, relation count, unconfirmed suggestions |
| `add(terms, relations)` | Bulk-insert terms and relations programmatically |
| `startup()` | Scan projects, build unified ontology, write Claude instructions |
| `briefing(project)` | Generate per-project context briefing |
| `heartbeat()` | Weekly cross-project activity summary |

### Package introspection

| Function | Purpose |
|---|---|
| `pkg_exports(package)` | List exported functions with argument signatures |
| `pkg_internals(package)` | List internal (non-exported) functions |
| `pkg_help(topic, package)` | Get help topic as markdown |

### Code analysis

| Function | Purpose |
|---|---|
| `symbols(project_dir)` | AST symbol index: function defs and calls |
| `blast_radius(fn, project)` | Find all callers of a function across projects |

### Feature hubs

| Function | Purpose |
|---|---|
| `hub(name, content)` | Create/update a feature hub markdown file |
| `hubs()` | List all hubs with their wikilink references |

## Vault conventions

### Frontmatter

```yaml
---
id: ONTO:0000042
type: term
aliases:
  - NN
  - ANN
---
```

- `id:` is the stable identifier. Optional until promoted. Format: `PREFIX:NNNNNNN` (7-digit zero-padded).
- `type: term` marks a note as an ontology term. Also inferred if the note is a typed-link target.
- `aliases:` become OBO synonyms.

### Typed relations (inline fields)

```markdown
is_a:: [[dev_tooling]]
part_of:: [[cornyverse]]
uses:: [[yaml]]
```

Dataview-style inline fields. The relation name is the key, the wikilink target is the value. These are the canonical typed edges.

### Untyped links

Regular `[[wikilinks]]` are indexed but treated as weak signals. They feed `suggest()`, not the ontology directly.

### What counts as a term

A note is a term if ANY of:
- It has `id:` in frontmatter
- It has `type: term` in frontmatter
- It appears as the target of a typed relation

Everything else is just a note.

## Index format

Three TSV files in `{vault_path}/.ontolite/`:
- `terms.tsv` — id, name, filepath, aliases (pipe-separated), promoted (0/1), updated_at
- `relations.tsv` — subject_id, relation_type, object_id, confirmed (0/1), source (inline|suggested|manual|auto)
- `files.tsv` — filepath, hash, parsed_at (for incremental rebuild)

## ID generation

When `promote()` is called:
1. Find the max existing numeric ID in the index
2. Increment by 1
3. Write `id: PREFIX:NNNNNNN` into the file's frontmatter
4. Update the index

The prefix is configurable, default `ONTO`. This is a deliberate action, not automatic.

## The suggest/confirm loop

`suggest()` examines untyped links and proposes typed relations based on:
- Folder structure (co-location as weak `part_of` signal)
- Heading context (link under "## Methods" -> maybe `uses`)
- Link frequency patterns

Suggestions are written to `relations.tsv` with `confirmed = 0` and `source = 'suggested'`. Troy reviews them. You do NOT treat unconfirmed suggestions as facts.

When Troy confirms: he either adds the typed inline field to the markdown (source of truth) and re-indexes, or tells you to do it.

## Correction protocol

When Troy says something like "that's not is_a, that's uses":
1. Edit the markdown file: change the inline field
2. Run `index_vault()` to pick up the change
3. Do NOT manually patch the index files

When Troy says "that note shouldn't be a term":
1. Remove `type: term` and `id:` from frontmatter if present
2. The note remains as a file but drops out of the ontology on next index

## Output format for queries

`query()` returns a data.frame. When you're calling from the command line, print it as TSV for easy parsing:

```r
res <- basalt::query("neural_networks", "is_a", "ancestors", vault_path = "~/.cache/basalt/vault")
write.table(res, stdout(), sep = "\t", row.names = FALSE, quote = FALSE)
```

## File structure

```
R/
  index.R      — index_vault(), file parsing, frontmatter extraction
  query.R      — query(), graph traversal
  suggest.R    — suggest(), heuristic relation proposals
  promote.R    — promote(), ID generation and writeback
  emit.R       — emit_obo(), OBO format output
  status.R     — status()
  add.R        — add(), bulk insert
  briefing.R   — briefing(), project context
  heartbeat.R  — heartbeat(), cross-project summary
  startup.R    — startup(), unified bootstrapper
  pkg.R        — pkg_exports(), pkg_internals(), pkg_help(), Rd-to-md
  symbols.R    — symbols(), AST symbol index
  blast.R      — blast_radius(), impact analysis
  hubs.R       — hub(), hubs(), feature hub files
  db.R         — load_index(), save_index(), TSV I/O
  parse.R      — frontmatter/link parsing
inst/
  tinytest/    — tests
man/           — tinyrox
DESCRIPTION
NAMESPACE
```

## Testing

- tinytest
- Every core function gets at least one happy-path and one edge-case test.
- Index tests use a temp directory, not a real vault.

## Things you should NOT do

- Do not add dependencies beyond yaml without asking Troy.
- Do not silently promote notes to terms.
- Do not treat suggested relations as confirmed.
- Do not build an MCP server or HTTP layer. This is R-callable functions, nothing more.
- Do not use tidyverse functions or pipes.

## Things you SHOULD do

- When Troy asks you to query the ontology, actually call the functions. Don't guess from memory.
- When you notice an untyped link that should probably be typed, mention it. Don't auto-fix it.
- When emitting OBO, include the human-readable comment after IDs: `is_a: ONTO:0000007 ! Machine Learning Method`
- Keep functions short. If a function is over 80 lines, split it.
