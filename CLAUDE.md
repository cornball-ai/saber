# CLAUDE.md

## What this is

A small R package that maintains a live ontology from a markdown vault. You (Claude Code) are the primary consumer. Troy is the editor-of-last-resort.

The vault (markdown files with frontmatter and typed links) is the source of truth. The SQLite index is derived. Never edit the index directly — edit the markdown, then rebuild.

This package is new and should evolve rapidly depending on how we end up using it. Don't be afraid to propose big changes depending on what's working.

## Package name

basalt, might change it to wwud (what would you, as in What Would Troy Do)

## Design philosophy

- Base R. No tidyverse. No pipes.
- One real dependency: RSQLite. Everything else is base.
- YAML frontmatter parsing: yaml package
- OBO emit is just writeLines(). No serialization library.
- CRAN-viable. 
- Apache-2.0 license (consistent with cornyverse core packages).

## How you use this package

Shell into R:

```
r 'library(basalt); ont_query("neural_networks", "is_a", "ancestors")'
```

Use the query results to build context, pick retrieval targets, expand search terms to descendants, or verify relationships before asserting them in conversation.

## Core functions

| Function | Purpose |
|---|---|
| `ont_index(vault_path)` | Parse markdown files, build/update SQLite index |
| `ont_query(term, relation, direction)` | Traverse the typed graph (ancestors, descendants, siblings) |
| `ont_suggest(vault_path)` | Propose typed edges from untyped links. Returns candidates, NOT facts. |
| `ont_promote(term, vault_path)` | Write a stable `id:` into a file's frontmatter |
| `ont_emit_obo(db_path, outfile)` | Snapshot the current ontology to OBO format |
| `ont_status(db_path)` | Summary stats: term count, relation count, unconfirmed suggestions |

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
uses:: [[RSQLite]]
```

Dataview-style inline fields. The relation name is the key, the wikilink target is the value. These are the canonical typed edges.

### Untyped links

Regular `[[wikilinks]]` are indexed but treated as weak signals. They feed `ont_suggest()`, not the ontology directly.

### What counts as a term

A note is a term if ANY of:
- It has `id:` in frontmatter
- It has `type: term` in frontmatter
- It appears as the target of a typed relation

Everything else is just a note.

## SQLite schema

One database, default location `{vault_path}/.ontolite/index.db`.

Tables:
- `terms` — id, name, filepath, aliases (JSON array), promoted (bool), updated_at
- `relations` — subject_id, relation_type, object_id, confirmed (bool), source (frontmatter|inline|suggested)
- `files` — filepath, hash, parsed_at (for incremental rebuild)

## ID generation

When `ont_promote()` is called:
1. Find the max existing numeric ID in the db
2. Increment by 1
3. Write `id: PREFIX:NNNNNNN` into the file's frontmatter
4. Update the index

The prefix is configurable, default `ONTO`. This is a deliberate action, not automatic.

## The suggest → confirm loop

`ont_suggest()` examines untyped links and proposes typed relations based on:
- Folder structure (co-location as weak `part_of` signal)
- Heading context (link under "## Methods" → maybe `uses`)
- Link frequency patterns

Suggestions are written to the `relations` table with `confirmed = FALSE` and `source = 'suggested'`. Troy reviews them. You do NOT treat unconfirmed suggestions as facts.

When Troy confirms: he either adds the typed inline field to the markdown (source of truth) and re-indexes, or tells you to do it.

## Correction protocol

When Troy says something like "that's not is_a, that's uses":
1. Edit the markdown file: change the inline field
2. Run `ont_index()` to pick up the change
3. Do NOT manually patch the SQLite

When Troy says "that note shouldn't be a term":
1. Remove `type: term` and `id:` from frontmatter if present
2. The note remains as a file but drops out of the ontology on next index

## Output format for queries

`ont_query()` returns a data.frame. When you're calling from the command line, print it as TSV for easy parsing:

```r
res <- ont_query("neural_networks", "is_a", "ancestors")
write.table(res, stdout(), sep = "\t", row.names = FALSE, quote = FALSE)
```

## File structure

```
R/
  index.R        — ont_index(), file parsing, frontmatter extraction
  query.R        — ont_query(), graph traversal
  suggest.R      — ont_suggest(), heuristic relation proposals
  promote.R      — ont_promote(), ID generation and writeback
  emit.R         — ont_emit_obo(), OBO format output
  status.R       — ont_status()
  db.R           — schema init, connection helpers
  parse.R        — 
inst/
  sql/
    schema.sql   — CREATE TABLE statements
man/             — tinyrox
tests/
  testthat/
DESCRIPTION
NAMESPACE
```

## Testing

- tinytest
- Every core function gets at least one happy-path and one edge-case test.
- Index tests use a temp directory, not a real vault.

## Things you should NOT do

- Do not add dependencies beyond RSQLite without asking Troy.
- Do not silently promote notes to terms.
- Do not treat suggested relations as confirmed.
- Do not build an MCP server or HTTP layer. This is a little r-callable functions, nothing more.
- Do not use tidyverse functions or pipes.

## Things you SHOULD do

- When Troy asks you to query the ontology, actually call the functions. Don't guess from memory.
- When you notice an untyped link that should probably be typed, mention it. Don't auto-fix it.
- When emitting OBO, include the human-readable comment after IDs: `is_a: ONTO:0000007 ! Machine Learning Method`
- Keep functions short. If a function is over 80 lines, split it.
