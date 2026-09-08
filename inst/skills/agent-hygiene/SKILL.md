---
name: agent-hygiene
description: >
  Audit and reconcile agent instruction files and skill roots so Claude Code,
  Codex, and corteza read one shared instruction body and one flat skill hub.
  Use when instruction files or skills drift, duplicate, or diverge between
  agents, when adding or moving a package-owned skill, or when cleaning up
  agent configuration on a new machine.
---

# agent-hygiene

Keep one instruction body and one skill set across agents. Every agent reads
its own native path; the paths are symlinks to the same files. This skill
audits that layout and repairs the symlinks. It never deletes content.

Read [references/layout.md](references/layout.md) for the contract, how each
consumer deduplicates, and the known limits before changing anything.

## The layout in one screen

```
~/.config/agents/GLOBAL.md  -> shared instructions   (saber's shared path)
~/.claude/CLAUDE.md         -> same file             (Claude Code native)
~/.codex/AGENTS.md          -> same file             (Codex native)
<project>/AGENTS.md         -> <project>/CLAUDE.md   (one project file)

<hub>/<skill>/SKILL.md                      personal skills, tracked
<hub>/<skill> -> <pkg>/inst/skills/<skill>  package skills, symlinks
~/.claude/skills  -> <hub>                  Claude Code reads the hub
~/.agents/skills  -> <hub>                  Codex reads the hub
corteza instruction_roots: <hub> (0.7.1.47+), else each <pkg>/inst/skills
```

The hub, package checkouts, and agent roots are declared once in a DCF
manifest, by default `~/.config/agents/skills.dcf`:

```
Hub: ~/skills
Packages: ~/saber, ~/pensar
AgentRoots: ~/.claude/skills, ~/.agents/skills
```

## Procedure

1. Audit, read-only:

   ```bash
   script="$(Rscript -e 'cat(system.file("skills/agent-hygiene/scripts/agent-hygiene.R", package = "saber"))')"
   Rscript "$script" audit
   ```

   It reports whether the global instruction names all exist and resolve to
   one file, whether the project's AGENTS.md and CLAUDE.md are one file, what
   each hub entry is (local, package link, foreign link, dangling), name and
   duplicate problems, claude.ai-synced skills inside the hub, agent roots
   that are not the hub, corteza roots that cannot see a package, and Claude
   plugins that duplicate hub skills. Exit status 1 means drift was found.

   To see every skill, active or archived, with its owner and description:

   ```bash
   Rscript "$script" list
   Rscript "$script" list --html ~/Sync/skills.html
   ```

2. Decide with the user what moves. Retire a skill by moving it under a
   hidden `.archive/` in the hub: Claude Code reads one level and Codex
   skips hidden directories, so nothing there loads. Migrate reusable
   package instructions into that package's `inst/skills/<skill>/`. Keep
   personal policy and host inventory in the hub or dotfiles. Ask before
   changing standing instructions or deleting anything.

3. Link:

   ```bash
   Rscript "$script" link --dry-run
   Rscript "$script" link
   ```

   Creates or repairs the hub's package symlinks and points each agent root
   at the hub. A real directory in the way is reported, not replaced; move it
   aside first. Add new link names to the hub's `.gitignore`.

4. Verify in a fresh process, not by reading the config back:
   - `Rscript "$script" audit` exits 0.
   - A new Claude Code or Codex session lists the hub's skills once each.
   - corteza's catalog lists the package skills without `symlink_escape`
     or `missing_root` diagnostics.

## Do not

- Delete or overwrite a real directory to make a link fit.
- Commit hub symlinks; they are absolute and machine-specific.
- Restate shared policy inside a project instruction file. Content dedup
  only catches byte-identical text; topical duplication needs an edit.
- Point a corteza older than 0.7.1.47 at the hub; it refuses links that
  escape a root, as `skill_manifest()` still does. List each package's
  `inst/skills` directory for those versions.
