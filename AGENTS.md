# dot-pi — Agent Guide

> Quick-reference for LLM coding agents (Cursor, pi, Copilot) working in this repo.
> For human-facing docs, see `docs/` or the deployed MkDocs site.

## What This Repo Is

dot-pi is a **dotfiles-style** repository for [pi](https://github.com/PlebeiusGaragicus/pi-mono) (a coding agent). It manages multiple isolated agent configurations via the `PI_CODING_AGENT_DIR` environment variable. When set, pi loads all config (extensions, agents, prompts, skills, sessions, models, themes) from that directory instead of `~/.pi/agent/`.

Two kinds of agent configurations live here:

- **Team-style agents** (`agents/`): Multi-agent setups with the `subagent-teams` extension for orchestrated delegation (single, parallel, chain).
- **Standalone agents** (`agents/`): Single-agent setups with custom extensions and no subagent orchestration.

Either kind can run **in-situ** (in the user's current directory) or as a **workspace** agent (in a fresh dated directory). A `workspace.conf` file marks which mode to use — see "Workspace Agents" under Key Concepts.

## Directory Structure

```
dot-pi/
├── AGENTS.md                 # This file
├── README.md                 # Human-facing overview
├── dotpi                     # CLI: setup, create, create-agent, list, link-skill, link-auth
├── commands/                 # Subcommand scripts (sourced by dotpi)
├── env.sh                    # Shell environment (source in .zshrc/.bashrc)
├── dispatch-agent            # Symlink target in bin/ (dispatches commands to agents)
├── mkdocs.yml                # MkDocs config for docs site
│
├── shared/                   # Reusable resources (never used as PI_CODING_AGENT_DIR directly)
│   ├── extensions/           # Shared extension source code (*.ts files and directories)
│   ├── skills/               # Shared skill definitions (each skill is a directory with SKILL.md)
│   ├── themes/               # Shared themes (JSON)
│   ├── bin/                  # Downloaded binaries (fd, rg) — gitignored contents
│   ├── models.json           # Symlink → ~/.pi/agent/models.json (system pi config; managed by `dotpi setup`)
│   └── settings.json         # Pi settings (gitignored; bootstrapped from bootstrap/settings.json.example)
│
├── bootstrap/                # Tracked seed/template files (copied into place on first run)
│   ├── model_roles.example   # Template for per-role model env vars (-> ./model_roles)
│   ├── settings.json.example # Template for shared/settings.json (auto-copied by install / dotpi sync)
│   └── plebchat-models.json  # Reference catalogue of known plebchat models (manual lookup)
│
├── agents/                   # Team-style and standalone agent directories
├── workspaces/               # Ephemeral workspace directories (gitignored contents)
├── docs/                     # MkDocs documentation source
└── REFERENCES/               # Local-only sibling checkouts for agent context (gitignored).
                              # Optional manual `git clone`s of related projects (pi-mono,
                              # gstack, qmd, plannotator, etc.) so agents working in this
                              # repo can read their source. See REFERENCE-REPOS.md.
                              # Never loaded as PI_CODING_AGENT_DIR; never managed by dotpi.
```

### Local Config Files (gitignored, per-machine)

These files are **never tracked**. They're created locally by the installer or `dotpi setup`, edited like a `.env`, and persist across pulls. If any are missing, bootstrap from the `.example` sibling.

| File | Source | Purpose |
|------|--------|---------|
| `model_roles` | `cp bootstrap/model_roles.example model_roles` (or `dotpi setup`) | Per-role model env vars (`AGENTIC_MODEL`, `THINKING_MODEL`, …). Sourced by `env.sh`. |
| `shared/settings.json` | `cp bootstrap/settings.json.example shared/settings.json` (auto on `install` / `dotpi sync`) | Pi runtime settings (theme, defaults). Symlinked into every agent config. |
| `shared/models.json` | Symlink → `~/.pi/agent/models.json` (created by installer or `dotpi sync`) | Multi-provider model config shared with system pi. `dotpi setup` edits the system file. |
| `*/auth.json` | `dotpi link-auth` or set up by pi on first run | Per-agent credentials. |
| `REFERENCES/*` | Optional manual `git clone`s; see REFERENCE-REPOS.md` | Sibling project source for agents to read. |

### Team Directory Layout (`agents/<name>/`)

Each is a complete `PI_CODING_AGENT_DIR` root:

```
agents/<name>/
├── extensions/               # Symlinked from shared/extensions/ (see Symlink Patterns)
├── agents/                   # Subagent definitions (team-agentname.md)
├── prompts/                  # Prompt templates (slash-command workflows)
├── skills/                   # Per-skill symlinks (add with dotpi link-skill)
├── themes/                   # Per-theme symlinks from shared/themes/
├── team-prompt.md            # Orchestrator config (frontmatter) + system prompt (body)
├── pi-args                   # (optional) Default CLI flags for the orchestrator (read by dispatch-agent)
├── banner.txt                # Startup branding (ASCII art + usage text)
├── workspace.conf            # (optional) Marks as workspace agent; lists subdirs to pre-create
├── bin/                      # → shared/bin/
├── models.json               # → shared/models.json
├── sessions/                 # Runtime (gitignored)
├── settings.json             # → shared/settings.json
└── auth.json                 # API auth (gitignored, may be symlinked)
```

### Standalone Agent Layout (`agents/<name>/`)

Same `PI_CODING_AGENT_DIR` root but without subagent orchestration:

```
agents/<name>/
├── extensions/
│   ├── <name>/               # Custom extension (index.ts)
│   ├── say.ts                # Shared (default scaffold): TTS / say tool — symlinked from shared
│   ├── run-finish-notify.ts, startup-branding.ts   # Shared (default scaffold)
│   └── ...                   # Optional: e.g. agent-prompt.ts — symlink manually if you use AGENT.md
├── AGENT.md                  # (optional, not scaffolded) YAML + body — symlink agent-prompt.ts to load
├── SYSTEM.md                 # Starter system prompt (scaffolded by dotpi; replaces pi default)
├── APPEND_SYSTEM.md          # (optional) Appends to pi's default system prompt (pi-native)
├── pi-args                   # (optional) Default CLI flags, one per line (read by dispatch-agent; end file per IMPORTANT line)
├── skills/                   # Per-skill symlinks from shared/skills/ (use dotpi link-skill to add)
├── themes/                   # Per-theme symlinks from shared/themes/
├── banner.txt                # Startup branding (ASCII art + usage text)
├── workspace.conf            # (optional) Marks as workspace agent; lists subdirs to pre-create
├── bin/                      # → shared/bin/
├── models.json               # → shared/models.json
├── sessions/                 # Runtime (gitignored)
├── settings.json             # → shared/settings.json
└── auth.json                 # API auth (gitignored, may be symlinked)
```

No `agents/` subdirectory, no `team-prompt.md`. The main pi process IS the agent. Custom behavior comes from the extension.

**Prompt and tool customization** (combine as needed):

1. **`SYSTEM.md` / `APPEND_SYSTEM.md`** (pi-native): `SYSTEM.md` replaces pi's default system prompt entirely; `APPEND_SYSTEM.md` appends to it. No extension needed — pi discovers these from `PI_CODING_AGENT_DIR` at startup.
2. **`pi-args`** (via `dispatch-agent`): plain text file with default CLI flags (e.g. `--tools websearch`, `--no-tools`, `--no-skills`, `--no-context-files`), one per line. The `dispatch-agent` script prepends these to the `pi` invocation. A missing final newline is tolerated. Non-coding agents and reusable subagents should usually include `--no-context-files` so workspace runs inside this repo do not inherit `AGENTS.md` or other coding context files. Coding agents such as `coder` may intentionally omit it.
3. **`AGENT.md`** (optional, legacy): YAML frontmatter sets `tools` and/or `model`; body appended to the system prompt. Requires symlink: `ln -sf ../../../shared/extensions/agent-prompt extensions/agent-prompt` — the `agent-prompt` shared extension reads `AGENT.md`. New `dotpi create-agent` scaffolds do not link this file by default.

## Key Concepts

### Extensions

TypeScript modules in `<agentDir>/extensions/`. Auto-discovered by pi on startup.

**Shape**: Default-exported function `(pi: ExtensionAPI) => void`. Can be a single file (`extensions/foo.ts`) or a directory with an entry point (`extensions/foo/index.ts`).

**Multi-file extensions**: An `index.ts` can import sibling `.ts` modules via `./name.js` specifiers (standard Node ESM convention). Example: `subagent-teams/index.ts` imports from `./agents.js`. **Caveat**: multi-file imports may fail in **symlinked** shared extensions (jiti's `moduleCache: false` + symlink resolution can cause "Reflect.get called on non-object"). Keep shared extensions (`shared/extensions/`) as single `index.ts` files. Multi-file splits are safe in per-agent custom extensions (`agents/<name>/extensions/<name>/`) which are real directories, not symlinks.

**Imports**:
```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";
import { getAgentDir, getMarkdownTheme, withFileMutationQueue, parseFrontmatter } from "@mariozechner/pi-coding-agent";
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
import { StringEnum } from "@mariozechner/pi-ai";
import { Type } from "@sinclair/typebox";
```

**Lifecycle hooks**:

| Hook | Signature | Can Return |
|------|-----------|------------|
| `before_agent_start` | `async (event) => ...` | `{ systemPrompt: string }` to override |
| `agent_end` | `async (event, ctx) => ...` | void |

`before_agent_start` does NOT receive `ctx`. Use direct TTY I/O for user interaction in this hook.
`agent_end` receives `ctx` with `ctx.ui.confirm(title, msg)`, `ctx.ui.notify(title, msg)`, `ctx.cwd`, `ctx.hasUI`.

**Tool registration**:
```typescript
pi.registerTool({
    name: "tool-name",
    label: "Display Label",
    description: "Description shown to the LLM",
    parameters: Type.Object({ /* Typebox schema */ }),
    async execute(toolCallId, params, signal, onUpdate, ctx) {
        // params: validated against parameters schema
        // signal: AbortSignal for cancellation
        // onUpdate: streaming partial results callback
        // ctx: { cwd, hasUI, ui: { confirm, notify } }
        return { content: [{ type: "text", text: "result" }] };
    },
    renderCall(args, theme, context) { /* optional TUI for tool invocation */ },
    renderResult(result, { expanded }, theme, context) { /* optional TUI for result */ },
});
```

**TUI rendering** (for `renderCall`/`renderResult`):
- `new Text(content, x, y)` — styled text
- `new Container()` with `.addChild(...)` — layout container
- `new Markdown(content, x, y, theme)` — rendered markdown (use `getMarkdownTheme()`)
- `new Spacer(lines)` — vertical spacing
- `theme.fg(colorName, text)` — foreground color (`"accent"`, `"muted"`, `"dim"`, `"error"`, `"success"`, `"warning"`, `"toolTitle"`, `"toolOutput"`)
- `theme.bold(text)` — bold text

**Key utilities**:
- `getAgentDir()` — returns resolved `PI_CODING_AGENT_DIR` path
- `withFileMutationQueue(path, fn)` — serialize file writes
- `parseFrontmatter<T>(content)` — returns `{ frontmatter: T, body: string }`

### Agent Definitions (Subagent `.md` Files)

Markdown files in `<teamDir>/agents/` with YAML frontmatter. Used by the `subagent-teams` extension.

```markdown
---
name: scout
description: Fast codebase recon
tools: read, grep, find, ls, bash
skills: skills/searxng
no-skills: true
model: haiku
team: recon
---

System prompt body (becomes --append-system-prompt for the child pi process).
```

| Field | Required | Description |
|-------|----------|-------------|
| `description` | **Yes** | If missing, the file is **skipped** entirely |
| `name` | No | Defaults from filename (part after first `-`) |
| `team` | No | Defaults from filename (part before first `-`); overrides filename |
| `tools` | No | Comma-separated tool whitelist; omit for all defaults |
| `skills` | No | Comma-separated skill paths (relative to team dir or absolute) |
| `no-skills` | No | `true` disables auto-discovery; combine with `skills` for explicit-only |
| `model` | No | Model override for this subagent |

**Naming convention**: `team-agentname.md` — first `-` separates team from agent name. Files without `-` have no team and are visible to all team filters.

### Skills

Markdown files (`SKILL.md`) that teach the agent how to use specific tools or workflows. NOT code — they are instructions injected into the agent's context.

```markdown
---
name: searxng
description: Search the web using a local SearXNG instance
allowed-tools: Bash
---

# SearXNG Web Search

Use this curl command to search: ...
```

| Frontmatter | Required | Description |
|-------------|----------|-------------|
| `name` | Yes | Skill identifier |
| `description` | Yes | Short description |
| `allowed-tools` | No | Restrict which tools the agent may use with this skill |

Skills live in `shared/skills/` and are symlinked per-skill into each agent config's `skills/` directory.

### Workspace Agents

Any team or standalone agent can run as a **workspace agent** by adding a `workspace.conf` file to its directory. When present, running the command (e.g. `deepresearch`) launches pi in a fresh dated directory (`workspaces/<name>/<timestamp>/`) inside a subshell, so the user's shell stays in its original directory after pi exits.

**`workspace.conf` format**: one subdirectory name per line. Lines starting with `#` are comments. Each listed directory is pre-created in the workspace before pi starts. A missing final newline is tolerated.

```
# agents/deepresearch/workspace.conf
sources
drafts
sessions
```

**To convert any existing agent config to workspace mode**: create `workspace.conf` in its directory (can be empty for a bare workspace, or list subdirectories).

**To scaffold a new workspace agent config**: use the `--workspace` flag with `dotpi`:
```bash
dotpi create --workspace my-research-team
dotpi create-agent --workspace my-scraper
```

**Resuming a workspace session**: Workspace agents support `--resume` and `--list`:
```bash
deepresearch --list                         # show existing workspaces
deepresearch --resume                       # resume most recent workspace
deepresearch --resume 2026-04-10            # resume workspace matching prefix
```
`--resume` cd's into the existing workspace directory and passes `--resume` to pi, so the session selector opens with the original session available. `--list` shows each workspace with a file count.

**Rebuilding symlinks**: Run `dotpi sync` to rebuild the `bin/` symlinks after adding or removing agent configs.

**Unified session logging**: When a workspace has a `sessions/` directory, both the orchestrator and all subagent sessions are stored there. The workspace launcher passes `--session-dir` to pi, and the `subagent-teams` extension detects the same directory for subagent sessions. This puts the complete run trajectory in one place for retrospective analysis. Legacy `subagent-sessions/` directories are also supported as a fallback.

Workspace contents are gitignored (`workspaces/*/`).

### Prompt Templates

Markdown files in `<teamDir>/prompts/` defining reusable workflows. Invoked via `/template-name` in pi chat. Typically chain subagents with `{previous}` placeholders and reference `$@` for user input.

### team-prompt.md

Per-team orchestrator instructions, read by `subagent-teams` on startup and appended to the main agent's system prompt. Describes the team's agents, workflows, and how to use the `subagent` tool.

## Symlink Patterns

`dotpi` wires shared resources into agent config directories via relative symlinks. The canonical sources live in `shared/` and are never loaded directly by pi.

**How it works:**

- **Extensions**: `dotpi create` symlinks a standard set of shared extensions into `<agentDir>/extensions/`. Team-style agents get the `subagent-teams` directory extension plus individual file extensions; `dotpi create-agent` symlinks `run-finish-notify.ts`, `startup-branding.ts`, and `say.ts` plus your stub under `extensions/<name>/`. Additional extensions from `shared/extensions/` can be manually symlinked as needed (including `agent-prompt.ts` if you use `AGENT.md`).
- **Skills**: `skills/` starts empty. Add symlinks with `dotpi link-skill <agent> <skill> [<skill> ...]` or `ln -sf ../../../shared/skills/<name> <dir>/skills/<name>`. Remove a symlink to exclude a skill.
- **Themes**: Each theme JSON in `shared/themes/` is symlinked individually into `<dir>/themes/`.
- **bin**: A single directory symlink (`bin → ../../shared/bin`) so pi downloads `fd`/`rg` once and all agent configs share them.
- **models.json**: A single file symlink (`models.json → ../../shared/models.json → ~/.pi/agent/models.json`). All agent configs and bare `pi` share one system config file. `dotpi setup` adds/edits/removes providers in the system file.
- **settings.json**: A single file symlink (`settings.json → ../../shared/settings.json`) so all agent configs share Pi preferences (theme, defaults, etc.).

All symlinks use relative paths (e.g. `../../../shared/extensions/...` for extensions under `agents/<name>/extensions/`).

**Do not edit symlink targets** — edit the source in `shared/` instead.

## Common Tasks

### Add a subagent to an existing team

1. Create `agents/<team>/agents/<team>-<name>.md` with YAML frontmatter (at minimum: `description`)
2. Write the system prompt in the markdown body
3. Update `agents/<team>/team-prompt.md` to mention the new agent
4. Optionally add/update prompt templates in `agents/<team>/prompts/`

### Create a new team

```bash
dotpi create <team-name>
dotpi create --workspace <team-name>   # workspace mode
```

Then: add agent `.md` files to `agents/`, write `team-prompt.md`, add prompt templates.

### Create a standalone agent

```bash
dotpi create-agent <agent-name>
dotpi create-agent --workspace <agent-name>   # workspace mode
```

**`dotpi create-agent`** writes **`SYSTEM.md`** and **`pi-args`**; it does **not** create **`AGENT.md`**. Customize **`SYSTEM.md`**, **`pi-args`**, and/or your stub extension. Add **`AGENT.md`** + symlink **`agent-prompt.ts`** only if you want YAML-driven tools/model.

Optionally edit `agents/<name>/extensions/<name>/index.ts` for custom tools or lifecycle hooks.

### Add a shared skill

1. Create `shared/skills/<name>/SKILL.md` with frontmatter (`name`, `description`)
2. Link into an agent config: `dotpi link-skill <agent> <name>` (or `ln -sf ../../../shared/skills/<name> <dir>/skills/<name>`)

### Write a custom extension

1. Create a directory: `<agentDir>/extensions/<ext-name>/index.ts`
2. Default-export a function: `(pi: ExtensionAPI) => void`
3. Use `pi.on(...)` for lifecycle hooks and `pi.registerTool(...)` for tools
4. See `shared/extensions/subagent-teams/index.ts` (1025 lines, full tool + TUI) and `agents/twenty-questions/extensions/twenty-questions/index.ts` (minimal hook + TUI overlay) as examples

## Files You Should and Shouldn't Edit

| Path Pattern | Editable? | Notes |
|-------------|-----------|-------|
| `shared/extensions/**/*.ts` | Yes | Shared extension source code |
| `shared/skills/*/SKILL.md` | Yes | Shared skill definitions |
| `shared/themes/*.json` | Yes | Shared themes |
| `agents/*/agents/*.md` | Yes | Subagent definitions |
| `agents/*/prompts/*.md` | Yes | Prompt templates |
| `agents/*/team-prompt.md` | Yes | Team orchestrator instructions |
| `*/banner.txt` | Yes | Startup branding (ASCII art + usage text) |
| `*/workspace.conf` | Yes | Workspace subdirectory list (presence marks workspace mode) |
| `agents/*/AGENT.md` | Yes | Agent prompt config (frontmatter: tools, model; body: system prompt append) |
| `agents/*/SYSTEM.md` | Yes | Replaces pi's default system prompt (pi-native) |
| `agents/*/APPEND_SYSTEM.md` | Yes | Appends to pi's default system prompt (pi-native) |
| `agents/*/pi-args` | Yes | Default CLI flags (read by `dispatch-agent`) |
| `agents/*/pi-args` | Yes | Optional default CLI flags for the team orchestrator (read by `dispatch-agent`) |
| `agents/*/extensions/**/*.ts` | Yes | Custom agent extensions |
| `dotpi` | Yes | CLI dispatcher (setup, create, list, link-skill, link-auth) |
| `commands/*.sh` | Yes | Subcommand scripts (sourced by dotpi) |
| `env.sh` | Yes | Shell environment (sourced from .zshrc/.bashrc) |
| `dispatch-agent` | Yes | Symlink target in bin/ (dispatches commands to agents) |
| `docs/**/*.md` | Yes | MkDocs documentation |
| `agents/*/extensions/*` | **No** | Symlinks — edit `shared/extensions/` instead |
| `agents/*/skills/*` | **No** | Symlinks — edit `shared/skills/` instead |
| `agents/*/themes/*` | **No** | Symlinks — edit `shared/themes/` instead |
| `*/models.json` (in agent configs) | **No** | Symlink chain → `shared/models.json` → `~/.pi/agent/models.json` |
| `shared/models.json` | **No** | Symlink → `~/.pi/agent/models.json`. Edit the system file directly or via `dotpi setup`. |
| `*/bin/` | **No** | Symlink — managed by pi runtime |
| `*/sessions/` | **No** | Runtime data — gitignored |
| `*/settings.json` (in agent configs) | **No** | Symlink — edit `shared/settings.json` |
| `*/auth.json` | **No** | Credentials — gitignored |
| `REFERENCES/**` | **No** | Local-only sibling checkouts; gitignored. Cloned manually for agent context (see `REFERENCE-REPOS.md`). |
| `model_roles` | Local | Per-machine config; gitignored. Written by `dotpi setup`, sourced by `env.sh`. Bootstrap manually with `cp bootstrap/model_roles.example model_roles`. |
| `shared/settings.json` | Local | Bootstrapped from `bootstrap/settings.json.example` by `install` / `dotpi sync`; gitignored thereafter. Edit freely; not tracked. |
| `bootstrap/*.example`, `bootstrap/plebchat-models.json` | Yes | Tracked seed/template files used to bootstrap local config. Edit to change defaults seen by new installs. |
| `VERSION` | Yes | Bump on releases. Surfaced via `dotpi --version`. |
