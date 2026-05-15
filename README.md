# saber

**Context engineering for R.**

saber ("to know" in Spanish, pronounced [sah-BEHR](https://www.youtube.com/watch?v=m3WBocsw9lw)) assembles agent context, traces blast radius across projects, and introspects packages so AI coding agents don't have to guess.

## Install

```r
install.packages("saber")
# or to install the development version
remotes::install_github("cornball-ai/saber")
```

## What it does

**13 exported functions.**

### Agent context

| Function | What it does |
|---|---|
| `agent_context()` | Assemble memory, identity, and instruction files for an agent |
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
| Understand a package's API | `r -e 'saber::pkg_exports("pkg")'` |
| Read function docs | `r -e 'saber::pkg_help("fn", "pkg")'` |
| Before renaming/changing a function | `r -e 'saber::blast_radius("fn", project = ".")'` |
| Understand a project's call graph | `r -e 'str(saber::symbols("."))'` |
| Discover R packages and deps | `r -e 'print(saber::projects())'` |
| What depends on a package | `r -e 'saber::find_downstream("pkg")'` |
| Project briefing | `r -e 'saber::briefing("project")'` |

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
        "matcher": "startup|resume",
        "hooks": [
          {
            "type": "command",
            "command": "Rscript /path/to/session-start.R codex",
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
| Understand a package's API | `r -e 'saber::pkg_exports("pkg")'` |
| Read function docs | `r -e 'saber::pkg_help("fn", "pkg")'` |
| Before renaming/changing a function | `r -e 'saber::blast_radius("fn", project = ".")'` |
| Understand a project's call graph | `r -e 'str(saber::symbols("."))'` |
| Discover R packages and deps | `r -e 'print(saber::projects())'` |
| What depends on a package | `r -e 'saber::find_downstream("pkg")'` |
| Project briefing | `r -e 'saber::briefing("project")'` |

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
            "command": "Rscript /path/to/session-start.R claude",
            "timeout": 15
          }
        ]
      }
    ]
  }
}
```

Every new session starts with the project's metadata, downstream dependents, and recent git commits already in context. The `claude` agent flag tells `briefing()` to skip Claude Code memory (which Claude Code autoloads separately).

## License

Apache-2.0
