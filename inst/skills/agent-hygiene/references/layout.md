# Agent files and skills: the contract

## Instruction files

One shared body, several names. `setup-agents.sh` in dotfiles (or an
equivalent) creates the links; nothing copies text.

| Name | Reader | Resolves to |
|------|--------|-------------|
| `~/.config/agents/GLOBAL.md` (or `$AGENTS_GLOBAL_MD`) | saber, corteza | shared file |
| `~/.claude/CLAUDE.md` (or `$CLAUDE_CONFIG_DIR/CLAUDE.md`) | Claude Code, natively | shared file |
| `~/.codex/AGENTS.md` (or `$CODEX_HOME/AGENTS.md`) | Codex, natively | shared file |
| `<project>/AGENTS.md` | Codex, corteza | `<project>/CLAUDE.md` |
| `<project>/CLAUDE.md` | Claude Code, corteza | project file |

How each consumer avoids loading a file twice:

- **Claude Code and Codex** load their native files themselves. The saber
  SessionStart hook (`session-start.R <agent> --native-shared`) compares the
  agent's native global file against the shared path with `normalizePath()`
  and skips the shared text when they are the same file. The hook never emits
  project files.
- **corteza** has no native autoload. `saber::context_manifest()` discovers
  the shared file, `AGENTS.md`, and `CLAUDE.md`, then drops any source whose
  canonical path matches an earlier one, and after that any source whose
  content hash and bytes match. With `AGENTS.md -> CLAUDE.md` the second
  project entry is excluded as `same_path`.
- **`saber::agent_context()`** (older API, still used by the hook for memory)
  picks the project file the agent does not autoload and checks `same_file()`
  before adding the other name.

Content dedup catches byte-identical text only. A project file that restates
shared policy in different words is loaded in full. Fix that by editing the
project file, and keep project files to facts the shared file cannot know.

## Skills

The Agent Skills specification (agentskills.io) is the shape every consumer
here reads: a directory named for the skill containing `SKILL.md` with
`name` and `description` frontmatter, optional `scripts/`, `references/`,
`assets/`. `name` must equal the directory name: lowercase letters, digits,
single hyphens, at most 64 characters.

Discovery. The root locations come from vendor documentation. The depth and
symlink behavior of Claude Code and Codex is empirical, observed with Claude
Code 2.1.265 and Codex 0.153.4 in September 2026, and may change:

| Consumer | Root | Depth | Symlinks |
|----------|------|-------|----------|
| Claude Code | `~/.claude/skills/<name>/SKILL.md`, `.claude/skills/` in the project, plugins | one level; a symlinked root works (verified 2.1.265) | entries may be symlinks; several names for one target load once |
| Codex | `~/.agents/skills/<name>/SKILL.md`, `.agents/skills/` in the repo and its parents, `/etc/codex/skills` | recursive, hidden directories skipped (verified 0.153.4) | symlinked skill folders and a symlinked root are followed |
| corteza | each `instruction_roots` path, recursive | any | followed inside the root; from 0.7.1.47 a symlink directly under the root is an alias walked as its own bounded tree; deeper escapes are skipped with `symlink_escape` |
| `saber::skill_manifest()` | package `inst/skills` or installed `skills`, plus named roots | any | followed inside the root; an escape fails that root |

Neither Claude Code nor Codex merges duplicate names across locations, so
one skill delivered twice (a hub entry plus a plugin, or two roots) shows up
twice. The canonical location for a reusable skill is its package's
`inst/skills/<skill>/`. The hub links to it; agents link to the hub.

### Layout

```
<hub>/
├── <skill>/SKILL.md                      personal skill, tracked in git
├── <skill> -> <pkg>/inst/skills/<skill>  package skill, symlink, gitignored
├── .archive/<skill>/                     retired; hidden so neither one-level nor recursive readers load it
~/.claude/skills -> <hub>
~/.agents/skills -> <hub>
```

corteza 0.7.1.47 and later can use the hub as its only `instruction_roots`
entry: a symlink directly under the root is an alias, walked as its own
bounded tree, with the id taken from the link name. Older versions refuse
those links, so for them `instruction_roots` lists each package's
`inst/skills` directory (the whole root, so every skill of the package is
found). The audit accepts either shape and flags a hub root on a corteza
that cannot read it.

If `~/.claude/skills` is a symlink, Claude Code's reserved `synced/`
directory for claude.ai skills would be created inside the hub; ignore it in
git.

### Manifest

A DCF file, by default `~/.config/agents/skills.dcf` or `$AGENTS_SKILLS_DCF`,
maintained in dotfiles and linked into place:

```
Hub: ~/skills
Packages: ~/saber, ~/pensar, ~/mx.client
AgentRoots: ~/.claude/skills, ~/.agents/skills
```

`Packages` are source checkouts with a `DESCRIPTION`; the script asks
`saber::skill_manifest(project_dirs = ...)` for their skills, so only skills
saber can parse are linked.

## Known limits

- The audit reads Claude plugin and corteza state with jsonlite when it is
  installed; without it those two sections are skipped.
- `link` uses `file.symlink()`; on Windows this needs symlink privileges.
- The hub's package symlinks are absolute paths. A clone on another machine
  needs the same checkouts and a `link` run.
