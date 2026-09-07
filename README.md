# saber

**Context engineering for R.**

saber ("to know" in Spanish, pronounced [sah-BEHR](https://www.youtube.com/watch?v=m3WBocsw9lw)) assembles agent context, traces blast radius across projects, and introspects packages so AI coding agents don't have to guess.

## Install

```r
install.packages("saber")
# or to install the development version
remotes::install_github("cornball-ai/saber")
```

## Running these examples

Examples below use `Rscript -e` for portability (Linux, macOS, Windows). On *nix (Linux and macOS), [littler](https://eddelbuettel.github.io/littler/) (`r`) gives faster startup, but `r -e` does not auto-print return values. These three are equivalent:

```bash
Rscript -e 'saber::pkg_exports("saber")'         # portable
r -p -e 'saber::pkg_exports("saber")'            # littler, auto-print
r -e 'print(saber::pkg_exports("saber"))'        # littler, explicit print
```

See the [tinyverse development toolchain](https://cornball.ai/posts/tinyverse-development-toolchain/) for the full setup.

## What it does

### Agent context

| Function | What it does |
|---|---|
| `agent_context()` | Assemble memory, identity, and instruction files for an agent |
| `context_manifest()` | Track context sources, native loading, deduplication, and budgets |
| `context_render()` | Render the manifest's selected context |
| `context_audit()` | Inspect source metadata and costs without printing source contents |
| `briefing()` | Generate a project briefing (metadata, dependents, git log) |

### Code intelligence

| Function | What it does |
|---|---|
| `symbols()` | Parse R source into function defs and calls via `getParseData()` |
| `blast_radius()` | Find every caller of a function, across projects |
| `fn_graph()` | Render a project's internal function call graph as SVG |
| `pkg_graph()` | Render a package dependency graph as SVG |
| `graph_svg()` | Force-directed graph renderer (used by `fn_graph` and `pkg_graph`) |

### Project discovery

| Function | What it does |
|---|---|
| `projects()` | Discover R package projects and their metadata |
| `find_downstream()` | Find all projects that depend on a given package |
| `default_exclude()` | Default directories to skip when scanning |

### Package introspection

| Function | What it does |
|---|---|
| `pkg_exports()` | List exported functions with argument signatures |
| `pkg_internals()` | List internal (non-exported) functions |
| `pkg_help()` | Pull help documentation as markdown |

## Examples

Assemble agent context from project and workspace files:

```r
# Claude Code agent in current project
saber::agent_context(agent = "claude")

# Codex agent with workspace identity
saber::agent_context(agent = "codex", workspace_dir = "~/.codex/workspace")
```

For explicit routing and source-level diagnostics:

```r
m <- saber::context_manifest(
    "corteza",
    shared_path = "~/.config/agents/GLOBAL.md",
    extra_sources = list(
        list(id = "runtime", kind = "runtime", order = -1,
             text = "R objects persist across turns."),
        list(id = "project_memory", kind = "memory", path = "notes/MEMORY.md")
    ),
    budgets = list(memory = list(max_lines = 100L))
)
saber::context_audit(m)       # metadata, counts, hashes, reasons; no source bodies
cat(saber::context_render(m)) # explicit request for the selected text
```

The new API reads shared preferences and prefers project `AGENTS.md`, falling
back to `CLAUDE.md`. It does not inherit the Claude global file or discover
memories implicitly. Supply memory paths and consumer-owned runtime layers
explicitly; set `discover = FALSE` to compose only supplied sources.
Consumers that load files natively must list those paths in `native_paths`.
Budgets are opt-in and their losses remain visible in the manifest and audit.
The existing `agent_context()` defaults and character return value are unchanged.

Generate a project briefing:

```r
saber::briefing("saber")
#> # Briefing: saber
#> _Generated 2026-03-25 00:30_
#>
#> ## Package
#> - **Name**: saber
#> - **Title**: Context Engineering for R
#> - **Version**: 0.7.0
#>
#> ## Recent commits
#> - 7983478 Add r-ci GitHub Actions workflow
#> - ...
```

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
#>   saber     Context Engineering    0.7.0    /home/troy/saber        ...

saber::find_downstream("jsonlite")
#>   [1] "chatterbox" "cornfab" "diffuseR" "llamaR" "llm.api"
#>   [6] "safetensors" "stt.api" "torch" "tts.api" "tuber" "whisper"
```

Inspect any installed package:

```r
saber::pkg_exports("saber")
saber::pkg_help("symbols", "saber")
```

Render a call graph:

```r
svg <- saber::fn_graph("~/myproject")
writeLines(svg, "~/callgraph.svg")
```

## How it works

`agent_context()` loads standard context files for AI coding agents: project instructions (AGENTS.md / CLAUDE.md), Claude Code memory files, global instructions, and agent identity files (SOUL.md). It skips files the agent already autoloads to avoid duplication.

`briefing()` assembles project context from DESCRIPTION metadata, downstream dependents, and recent git commits. It writes the markdown to the user cache directory so both the agent and user see the same context.

`symbols()` runs `getParseData()` on every `R/*.R` file in a project, extracts function definitions and call sites, and caches the results as RDS. Cache invalidates on file content changes (MD5).

`blast_radius()` builds on `symbols()`. It finds internal callers, then scans `~/` for any project whose DESCRIPTION declares a dependency on the target package. Traces the call graph across all of them. With `include = c("r", "examples", "vignettes")` it also flags references in roxygen `@examples` blocks and vignette code chunks.

`fn_graph()` and `pkg_graph()` render force-directed SVG graphs via a base R Fruchterman-Reingold simulation. No JavaScript — tooltips and links work via native SVG features.

## Codex integration

Codex reads `AGENTS.md` files automatically before it starts work. This repo ships one at the root; for your own R projects, add rules like these so Codex reaches for saber instead of guessing:

```markdown
## saber Toolchain Rules

Before working on R code, use the right tool for the job:

| Situation | Command |
|-----------|---------|
| Understand a package's API | `Rscript -e 'saber::pkg_exports("pkg")'` |
| Read function docs | `Rscript -e 'saber::pkg_help("fn", "pkg")'` |
| Before renaming/changing a function | `Rscript -e 'saber::blast_radius("fn", project = ".")'` |
| Understand a project's call graph | `Rscript -e 'str(saber::symbols("."))'` |
| Discover R packages and deps | `Rscript -e 'saber::projects()'` |
| What depends on a package | `Rscript -e 'saber::find_downstream("pkg")'` |
| Project briefing | `Rscript -e 'saber::briefing("project")'` |

**blast_radius is mandatory before renaming, moving, or changing the signature of any exported function.** It finds every caller across this project and all downstream projects. Skip it and you break things silently.
```

### SessionStart hook

saber ships a hook script that injects a project briefing into Codex at the start of every session. Find it with:

```r
system.file("scripts", "session-start.R", package = "saber")
```

Enable hooks in your Codex config (`~/.codex/config.toml`):

```toml
[features]
hooks = true
```

You can also enable the same feature from the CLI:

```bash
codex --enable hooks
```

Then add the hook to `~/.codex/hooks.json`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "Rscript --vanilla -e 'source(system.file(\"scripts\", \"session-start.R\", package = \"saber\"))' codex --native-shared",
            "timeout": 15,
            "statusMessage": "Loading saber briefing"
          }
        ]
      }
    ]
  }
}
```

Codex may require new or changed hooks to be reviewed before they run. Open
`/hooks` in Codex and approve the `session-start.R` command after adding it.

If you want neutral cross-agent preferences injected too, create
`~/.config/agents/GLOBAL.md`. The hook appends it automatically after the
project briefing. Set `AGENTS_GLOBAL_MD` if you want a different path.

Every new Codex session starts with the project's metadata, downstream dependents, Claude Code memory (if available), recent git commits, and optional global preferences already in context.

## Claude Code integration

Add the following to your `~/.claude/CLAUDE.md` to teach Claude Code how to use saber:

```markdown
### saber Toolchain Rules

Before working on R code, use the right tool for the job:

| Situation | Command |
|-----------|---------|
| Understand a package's API | `Rscript -e 'saber::pkg_exports("pkg")'` |
| Read function docs | `Rscript -e 'saber::pkg_help("fn", "pkg")'` |
| Before renaming/changing a function | `Rscript -e 'saber::blast_radius("fn", project = ".")'` |
| Understand a project's call graph | `Rscript -e 'str(saber::symbols("."))'` |
| Discover R packages and deps | `Rscript -e 'saber::projects()'` |
| What depends on a package | `Rscript -e 'saber::find_downstream("pkg")'` |
| Project briefing | `Rscript -e 'saber::briefing("project")'` |

**blast_radius is mandatory before renaming, moving, or changing the signature of any exported function.** It finds every caller across this project and all downstream projects. Skip it and you break things silently.
```

### SessionStart hook

saber ships a hook script that injects a project briefing into Claude Code's context at the start of every session. Find it with:

```r
system.file("scripts", "session-start.R", package = "saber")
```

Then add it to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "hooks": {
    "SessionStart": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "Rscript --vanilla -e 'source(system.file(\"scripts\", \"session-start.R\", package = \"saber\"))' claude --native-shared",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

Every new session starts with the project's metadata, downstream dependents, and recent git commits already in context. The `claude` agent flag tells `briefing()` to skip Claude Code memory (which Claude Code autoloads separately).

## Shared instructions across existing integrations

saber's existing `agent_context()` integration, consumer names (including
`llamar`), arguments, and defaults remain supported. The manifest API adds
provenance; it does not require replacing an established shared-file setup.
No new runtime dependencies are required.

Maintain one user-level instruction file and make native entrypoints refer to
it. For example, if `~/.claude/CLAUDE.md` is already the maintained source,
`~/.codex/AGENTS.md` and `~/.config/agents/GLOBAL.md` can be symlinks to it.
The latter is saber's existing shared-file convention, not another document
to maintain. `AGENTS_GLOBAL_MD` still selects a different shared path.
Inspect and reconcile existing files first; do not overwrite them or assume
that two different instruction files are interchangeable.

Within a project, keep `AGENTS.md` and `CLAUDE.md` as aliases of the same
maintained content (either symlink direction works). Keep the relative symlink
in version control where supported and exclude instruction files from R
package tarballs. On platforms without symlink support, an explicit maintained
copy or tested native import needs drift checks. Do not assume every consumer
understands Claude's import syntax. Corteza reads shared/project sources via
saber; its existing runtime and workspace layers remain consumer-owned.

The hook commands above are POSIX-shell examples. They resolve the installed
script at launch rather than pinning an R-version-specific library directory.
Adapt quoting for the shell on Windows. Existing absolute script paths and
littler invocations still work. No settings or hook trust are changed by
installing the package; merge registrations into the client's existing settings
and approve them through its normal trust workflow.

An empty `SessionStart` matcher covers all supported sources, including
startup, resume, clear, and compact. Keep unrelated hooks intact. The optional
trailing `--native-shared` flag (saber 0.7.2.4+) skips shared injection only if
the native global file and shared path resolve to the same readable file.
Codex's nonempty `AGENTS.override.md` takes precedence in this check. A missing,
distinct, or broken native path retains the shared injection. Without the flag,
the script preserves its historical behavior. Older saber scripts ignore the
extra flag and may duplicate shared text until upgraded; they do not lose it.
Use the flag only with normal native instruction loading enabled; client
exclusions and custom fallback rules need their own delivery verification.

Keep mandatory rules in native instructions so disabled hooks do not remove
them. Claude's Explore/Plan built-ins skip `CLAUDE.md`; `SubagentStart` cannot
inject additional context. The parent must pass task-critical constraints and
review results under the complete policy. General-purpose/custom subagent
delivery, imports, and each installed client version need direct probes.
See the official [Claude subagent documentation](https://code.claude.com/docs/en/sub-agents),
[Claude hooks reference](https://code.claude.com/docs/en/hooks), and
[Codex hooks documentation](https://learn.chatgpt.com/docs/hooks).

## License

Apache-2.0
