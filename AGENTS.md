# dot-pi — Agent Guide

> Quick-reference for LLM coding agents (Cursor, pi, Copilot) working in this repo.
> For human-facing docs, see `docs/` or the deployed MkDocs site.

## What This Repo Is

dot-pi is a **dotfiles-style** repository for [pi](https://github.com/PlebeiusGaragicus/pi-mono) (a coding agent). It manages multiple isolated agent configurations via the `PI_CODING_AGENT_DIR` environment variable. When set, pi loads all config (extensions, agents, prompts, skills, sessions, models, themes) from that directory instead of `~/.pi/agent/`.

Two kinds of agent configurations live here:

- **Multi-agent systems (MAS)** (`agents/`): An orchestrator agent using the `agent-orchestrator` extension to delegate to subagent config directories.
- **Standalone agents** (`agents/`): Single-agent setups with custom extensions and no subagent orchestration.

Either kind can run **in-situ** (in the user's current directory) or as a **workspace** agent (in a fresh dated directory). A `bootstrap.sh` file with `WORKSPACE_AGENT=1` marks workspace mode — see "Workspace Agents" under Key Concepts.

## Directory Structure

```
dot-pi/
├── AGENTS.md                 # This file
├── README.md                 # Human-facing overview
├── dotpi                     # CLI: setup, create, create-agent, list, link-skill, link-auth
├── commands/                 # Subcommand scripts (sourced by dotpi)
├── env.sh                    # Shell environment (source in .zshrc/.bashrc)
├── dispatch-agent            # Symlink target in bin/ (dispatches commands to agents)
├── lib/dispatch/             # Sourced modules used by dispatch-agent
├── mkdocs.yml                # MkDocs config for docs site
│
├── shared/                   # Reusable resources (never used as PI_CODING_AGENT_DIR directly)
│   ├── extensions/           # Shared extension source code (*.ts files and directories)
│   ├── extensions-common/    # Symlink bundle for standard top-level agent extensions
│   ├── extensions-subagents/ # Symlink bundle for default subagent extensions
│   ├── skills/               # Shared skill definitions (each skill is a directory with SKILL.md)
│   ├── themes/               # Shared themes (JSON)
│   ├── bin/                  # Downloaded binaries (fd, rg) — gitignored contents
│   ├── models.json           # Symlink → ~/.pi/agent/models.json (system pi config; managed by `dotpi setup`)
│   ├── auth.json             # Symlink → ~/.pi/agent/auth.json (API credentials; managed by pi)
│   └── settings.json         # Symlink → ~/.pi/agent/settings.json (Pi settings; managed by pi)
│
├── agents/                   # MAS and standalone agent directories
├── workspaces/               # Ephemeral workspace directories (gitignored contents)
├── docs/                     # MkDocs documentation source
└── REFERENCES/               # Local-only sibling checkouts for agent context (gitignored).
                              # Optional manual `git clone`s of related projects (pi-mono,
                              # gstack, qmd, plannotator, etc.) so agents working in this
                              # repo can read their source. See REFERENCE-REPOS.md.
                              # Never loaded as PI_CODING_AGENT_DIR; never managed by dotpi.
```

### Local Config Files (gitignored, per-machine)

These files are **never tracked**. They're created locally by the installer or `dotpi setup`, edited like a `.env`, and persist across pulls.

| File | Source | Purpose |
|------|--------|---------|
| `model-defaults` | Created by `dotpi sync` or `dotpi model-defaults` | Global fallback model aliases (`DEFAULT_AGENTIC_MODEL`, `DEFAULT_FAST_MODEL`, `DEFAULT_VLM_MODEL`). Loaded at agent launch time. |
| `shared/models.json` | Symlink → `~/.pi/agent/models.json` (created by installer or `dotpi sync`) | Multi-provider model config shared with system pi. `dotpi setup` edits the system file. |
| `shared/settings.json` | Symlink → `~/.pi/agent/settings.json` (created by `dotpi sync`) | Pi runtime settings (theme, defaults). Edit `~/.pi/agent/settings.json` or use pi's settings UI. |
| `shared/auth.json` | Symlink → `~/.pi/agent/auth.json` (created by `dotpi sync`) | API credentials. Edit `~/.pi/agent/auth.json` directly. |
| `*/auth.json` (under `agents/<name>/`) | Symlink → `../../shared/auth.json` (created by `dotpi sync` / scaffolds) | Same credential file for every top-level agent; edit `~/.pi/agent/auth.json`. Override with `dotpi link-auth` if needed. |
| `.exa.env`, `.tavily.env` | `/exa-api-key`, `/tavily-api-key`, or manual `SERVICE_API_KEY=value` | Repo-root keys for optional search extensions. Convention: **`.service-name.env`** (gitignored). |
| `REFERENCES/*` | Optional manual `git clone`s; see REFERENCE-REPOS.md` | Sibling project source for agents to read. |

### MAS Directory Layout (`agents/<name>/`)

Each is a complete `PI_CODING_AGENT_DIR` root:

```
agents/<name>/
├── extensions/               # Common bundle symlinks plus MAS-specific extensions
├── agents/                   # Subagent config directories or symlinks
├── prompts/                  # Prompt templates (slash-command workflows)
├── skills/                   # Per-skill symlinks (add with dotpi link-skill)
├── themes/                   # Per-theme symlinks from shared/themes/
├── README.md                 # Human-facing overview (orchestrator listings, prose)
├── USAGE.md                  # Man-style launcher help (agent help / -h / --help)
├── SYSTEM.md                 # Orchestrator system prompt
├── pi-args                   # (optional) Default CLI flags for the orchestrator (read by dispatch-agent)
├── banner.txt                # Startup branding (ASCII art + usage text)
├── bootstrap.sh              # (optional) Launch setup; WORKSPACE_AGENT=1 marks workspace mode
├── bin/                      # → shared/bin/
├── models.json               # → shared/models.json
├── sessions/                 # Runtime (gitignored)
├── settings.json             # → shared/settings.json
└── auth.json                 # → shared/auth.json (gitignored)
```

### Standalone Agent Layout (`agents/<name>/`)

Same `PI_CODING_AGENT_DIR` root but without subagent orchestration:

```
agents/<name>/
├── extensions/
│   ├── <name>/               # Custom extension (index.ts)
│   ├── say                   # Common bundle: TTS / say tool
│   ├── run-finish-notify, run-timer, startup-branding, model-default  # Common bundle
│   └── ...                   # Optional: e.g. agent-prompt.ts — symlink manually if you use AGENT.md
├── AGENT.md                  # (optional, not scaffolded) YAML + body — symlink agent-prompt.ts to load
├── README.md                 # Human-facing overview and design notes
├── USAGE.md                  # Man-style launcher help (agent help / -h / --help)
├── SYSTEM.md                 # Starter system prompt (scaffolded by dotpi; replaces pi default)
├── APPEND_SYSTEM.md          # (optional) Appends to pi's default system prompt (pi-native)
├── pi-args                   # (optional) Default CLI flags, one per line (read by dispatch-agent; end file per IMPORTANT line)
├── skills/                   # Per-skill symlinks from shared/skills/ (use dotpi link-skill to add)
├── themes/                   # Per-theme symlinks from shared/themes/
├── banner.txt                # Startup branding (ASCII art + usage text)
├── bootstrap.sh              # (optional) Launch setup; WORKSPACE_AGENT=1 marks workspace mode
├── bin/                      # → shared/bin/
├── models.json               # → shared/models.json
├── sessions/                 # Runtime (gitignored)
├── settings.json             # → shared/settings.json
└── auth.json                 # → shared/auth.json (gitignored)
```

No orchestrator subagent pool is required. The main pi process IS the agent. Custom behavior comes from the extension.

**Prompt and tool customization** (combine as needed):

1. **`SYSTEM.md` / `APPEND_SYSTEM.md`** (pi-native): `SYSTEM.md` replaces pi's default system prompt entirely; `APPEND_SYSTEM.md` appends to it. No extension needed — pi discovers these from `PI_CODING_AGENT_DIR` at startup.
2. **`pi-args`** (via `dispatch-agent`): plain text file with default CLI flags (e.g. `--model $DEFAULT_FAST_MODEL`, `--tools websearch`, `--no-tools`, `--no-skills`, `--no-context-files`), one per line. Model defaults come from repo-local `model-defaults` and optional agent-local `.model` files containing a raw `provider/model` id; empty `--model $DEFAULT_*` values are skipped so pi falls back to `settings.json`. A missing final newline is tolerated. Non-coding agents and reusable subagents should usually include `--no-context-files` so workspace runs inside this repo do not inherit `AGENTS.md` or other coding context files. Coding agents such as `coder` may intentionally omit it.
3. **`AGENT.md`** (optional, legacy): YAML frontmatter sets `tools` and/or `model`; body appended to the system prompt. Requires symlink: `ln -sf ../../../shared/extensions/agent-prompt extensions/agent-prompt` — the `agent-prompt` shared extension reads `AGENT.md`. New `dotpi create-agent` scaffolds do not link this file by default.

## Key Concepts

### Extensions

TypeScript modules in `<agentDir>/extensions/`. Auto-discovered by pi on startup.

**Shape**: Default-exported function `(pi: ExtensionAPI) => void`. Can be a single file (`extensions/foo.ts`) or a directory with an entry point (`extensions/foo/index.ts`).

**Multi-file extensions**: An `index.ts` can import sibling `.ts` modules via `./name.js` specifiers (standard Node ESM convention). Multi-file splits are safe in real extension directories and in shared extensions that are copied or resolved normally; be careful when changing symlinked extension layouts.

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

### Subagent Config Directories

Subagents are pi config directories under `<agentDir>/agents/` or project-local `.pi/agents/`. The `agent-orchestrator` extension discovers directories containing `SYSTEM.md` or `APPEND_SYSTEM.md`.

Recommended subagent files:

- `SYSTEM.md` or `APPEND_SYSTEM.md` -- the subagent prompt.
- `README.md` -- short description used in orchestrator listings.
- `USAGE.md` -- invocation contract appended to the orchestrator prompt.
- `pi-args` -- subagent-specific tools, context-file behavior, and model alias.

At the **root** of any `agents/<name>/` directory (MAS or standalone), **`USAGE.md`** is the file **`dispatch-agent`** prints for `<name> help`, `usage`, `-h`, and `--help` (plain text; use a man-style layout). **`README.md`** is for human- and agent-facing prose; launcher help does not fall back to it.

### Skills

Markdown files (`SKILL.md`) that teach the agent how to use specific tools or workflows. NOT code — they are instructions injected into the agent's context.

```markdown
---
name: searxng
description: Search the web using a local SearXNG instance
---

# SearXNG Web Search

Use this curl command to search: ...
```

| Frontmatter | Required | Description |
|-------------|----------|-------------|
| `name` | Yes | Skill identifier |
| `description` | Yes | Short description |

Skills live in `shared/skills/` and are symlinked per-skill into each agent config's `skills/` directory.

### Workspace Agents

Any MAS or standalone agent can run as a **workspace agent** by adding a `bootstrap.sh` file with `WORKSPACE_AGENT=1` to its directory. When present, running the command (e.g. `deepresearch`) launches pi in a fresh dated directory (`workspaces/<name>/<timestamp>/`) inside a subshell, so the user's shell stays in its original directory after pi exits.

`bootstrap.sh` is sourced by `dispatch-agent` before pi starts on fresh launches, resumes, and in-situ launches. Because it is sourced, exported variables persist into pi. Use it to create directories, export env vars, initialize daemons, and run health checks. The launcher captures stdout/stderr in `BOOTSTRAP_LOG` (`$WORKSPACE_DIR/bootstrap.log` for workspace agents).

```bash
# agents/deepresearch/bootstrap.sh
WORKSPACE_AGENT=1
export WORKSPACE_AGENT

mkdir -p "$WORKSPACE_DIR/sources" "$WORKSPACE_DIR/drafts" "$WORKSPACE_DIR/sessions"
export OUTPUT_DIR="$WORKSPACE_DIR/drafts"
```

The launcher provides `DOT_PI_DIR`, `AGENT_NAME`, `AGENT_DIR`, `WORKSPACE_AGENT`, `WORKSPACE_DIR` for workspace agents, `DOTPI_BOOTSTRAP_PHASE` (`fresh`, `resume`, or `in-situ`), and `BOOTSTRAP_LOG`.

Legacy `workspace.env` and `workspace.conf` files are no longer used by current launchers. Put workspace setup in `bootstrap.sh`.

**To convert any existing agent config to workspace mode**: create `bootstrap.sh` in its directory and include a top-level `WORKSPACE_AGENT=1` line.

**To scaffold a new workspace agent config**: use the `--workspace` flag with `dotpi`:
```bash
dotpi create --workspace my-research-mas
dotpi create-agent --workspace my-scraper
```

**Naming a workspace session**: Use `-n`/`--name` for the workspace name and a lone `-` before the prompt:
```bash
deepresearch -n creatine-loading-protocol - research creatine loading protocol
```
This creates a timestamped directory with a slug suffix, e.g. `workspaces/deepresearch/2026-04-28-091454--creatine-loading-protocol/`. Omitting the name keeps the timestamp-only directory.

**Resuming a workspace session**: Workspace agents support `resume` and `ls`, and dot-pi also provides a global picker:
```bash
deepresearch ls                             # show existing workspaces
deepresearch resume                         # choose a workspace by number
deepresearch resume 2026-04-10-125602       # resume exact workspace name
deepresearch resume 2026-04-10-125602 - continue # resume exact workspace with a prompt
deepresearch -p quick report                 # print final reply and exit
deepresearch -p -v quick report              # print final reply plus progress
resume                                      # choose from the 10 most recent workspaces
resume creatine                             # filter recent workspaces, then choose by number
```
`resume` cd's into the existing workspace directory and continues the latest pi session in that workspace. `ls` shows each workspace with a file count. The global `resume` command lists workspace agents together and prompts for a numbered selection.

**Rebuilding symlinks**: Run `dotpi sync` to rebuild `bin/` symlinks, ensure `shared/` symlinks to `~/.pi/agent/` exist, and link each `agents/<name>/auth.json` → `shared/auth.json`, after adding or removing agent configs.

**Unified session logging**: When a workspace has a `sessions/` directory, both the orchestrator and all subagent sessions are stored there. The workspace launcher passes `--session-dir` to pi, and `agent-orchestrator` uses the same directory for subagent sessions. This puts the complete run trajectory in one place for debugging.

Workspace contents are gitignored (`workspaces/*/`).

### Prompt Templates

Markdown files in `<agentDir>/prompts/` defining reusable workflows. Invoked via `/template-name` in pi chat. Typically chain subagents with `{previous}` placeholders and reference `$@` for user input.

## Symlink Patterns

`dotpi` wires shared resources into agent config directories via relative symlinks. The canonical sources live in `shared/` and are never loaded directly by pi.

**How it works:**

- **Extension implementations**: Shared extension source lives in `shared/extensions/`. Do not move source into bundle directories.
- **Common top-level extensions**: `shared/extensions-common/` contains symlinks for standard interactive/top-level agent extensions (`run-finish-notify`, `run-timer`, `startup-branding`, `say`, `save`, `model-default`). `dotpi create`, `dotpi create-agent`, and `dotpi sync` link this bundle into top-level `agents/<name>/extensions/`.
- **Subagent extensions**: `shared/extensions-subagents/` contains default subagent extension symlinks. Reusable subagents live canonically under `subagents/<name>/` and are symlinked into MAS roots (`agents/<mas>/agents/<name> -> ../../../subagents/<name>`). `dotpi sync` links the subagent bundle into canonical reusable subagents and MAS-local subagent directories. Subagents do not get the full common top-level bundle.
- **Specialized extensions**: MAS roots link `agent-orchestrator` explicitly. Other one-off extensions (`agent-prompt`, `tavily`, `moods`, `plan-mode`, etc.) are linked intentionally per agent as needed.
- **Skills**: `skills/` starts empty. Add symlinks with `dotpi link-skill <agent> <skill> [<skill> ...]` or `ln -sf ../../../shared/skills/<name> <dir>/skills/<name>`. Remove a symlink to exclude a skill.
- **Themes**: Each theme JSON in `shared/themes/` is symlinked individually into `<dir>/themes/`.
- **bin**: A single directory symlink (`bin → ../../shared/bin`) so pi downloads `fd`/`rg` once and all agent configs share them.
- **models.json**: A single file symlink (`models.json → ../../shared/models.json → ~/.pi/agent/models.json`). All agent configs and bare `pi` share one system config file. `dotpi setup` adds/edits/removes providers in the system file.
- **settings.json**: A single file symlink (`settings.json → ../../shared/settings.json → ~/.pi/agent/settings.json`). All agent configs share Pi preferences (theme, defaults, etc.). Edit `~/.pi/agent/settings.json` directly or use pi's settings UI.
- **auth.json**: A single file symlink (`auth.json → ../../shared/auth.json → ~/.pi/agent/auth.json`). All agent configs share one credential store. Edit `~/.pi/agent/auth.json` directly. `dotpi sync` creates or repairs the `shared/` and agent-level symlinks. Use `dotpi link-auth` only when an agent must point at a different `auth.json`.

All symlinks use relative paths (e.g. `../../../shared/extensions-common/...` for common extensions under `agents/<name>/extensions/`).

**Do not edit symlink targets at the agent root for models, settings, or auth** — edit the canonical files in `~/.pi/agent/` (or use `dotpi setup` for provider configuration) instead.

## Common Tasks

### Add a subagent to an existing MAS

1. Create or link `agents/<mas>/agents/<name>/`
2. Add `SYSTEM.md` or `APPEND_SYSTEM.md`
3. Add `README.md`, `USAGE.md`, and subagent-specific `pi-args` when needed
4. Update `agents/<mas>/SYSTEM.md` if the orchestrator needs workflow-specific instructions

### Create a new MAS

```bash
dotpi create <mas-name>
dotpi create --workspace <mas-name>   # workspace mode
```

Then: add subagent directories under `agents/`, write the orchestrator `SYSTEM.md`, add prompt templates.

### Create a standalone agent

```bash
dotpi create-agent <agent-name>
dotpi create-agent --workspace <agent-name>   # workspace mode
```

**`dotpi create-agent`** writes **`SYSTEM.md`**, **`pi-args`**, **`README.md`**, and **`USAGE.md`**; it does **not** create **`AGENT.md`**. Customize **`SYSTEM.md`**, **`USAGE.md`** (launcher synopsis), **`pi-args`**, and/or your stub extension. Add **`AGENT.md`** + symlink **`agent-prompt.ts`** only if you want YAML-driven tools/model.

Optionally edit `agents/<name>/extensions/<name>/index.ts` for custom tools or lifecycle hooks.

### Add a shared skill

1. Create `shared/skills/<name>/SKILL.md` with frontmatter (`name`, `description`)
2. Link into an agent config: `dotpi link-skill <agent> <name>` (or `ln -sf ../../../shared/skills/<name> <dir>/skills/<name>`)

### Write a custom extension

1. Create a directory: `<agentDir>/extensions/<ext-name>/index.ts`
2. Default-export a function: `(pi: ExtensionAPI) => void`
3. Use `pi.on(...)` for lifecycle hooks and `pi.registerTool(...)` for tools
4. See `shared/extensions/agent-orchestrator/index.ts` (full subagent tool + TUI) and `agents/twenty-questions/extensions/twenty-questions/index.ts` (minimal hook + TUI overlay) as examples

## Files You Should and Shouldn't Edit

| Path Pattern | Editable? | Notes |
|-------------|-----------|-------|
| `shared/extensions/**/*.ts` | Yes | Shared extension source code |
| `shared/extensions-common/*` | Yes | Symlink bundle for standard top-level agent extensions |
| `shared/extensions-subagents/*` | Yes | Symlink bundle for default subagent extensions |
| `shared/skills/*/SKILL.md` | Yes | Shared skill definitions |
| `shared/themes/*.json` | Yes | Shared themes |
| `agents/*/agents/*/SYSTEM.md` | Yes | Subagent system prompts |
| `agents/*/USAGE.md` | Yes | Man-style launcher help for `agent help` / `-h` / `--help` |
| `agents/*/agents/*/USAGE.md` | Yes | Subagent invocation contracts (orchestrator prompt) |
| `agents/*/prompts/*.md` | Yes | Prompt templates |
| `*/banner.txt` | Yes | Startup branding (ASCII art + usage text) |
| `*/bootstrap.sh` | Yes | Launch setup; `WORKSPACE_AGENT=1` marks workspace mode |
| `agents/*/AGENT.md` | Yes | Agent prompt config (frontmatter: tools, model; body: system prompt append) |
| `agents/*/SYSTEM.md` | Yes | Replaces pi's default system prompt (pi-native) |
| `agents/*/APPEND_SYSTEM.md` | Yes | Appends to pi's default system prompt (pi-native) |
| `agents/*/pi-args` | Yes | Default CLI flags (read by `dispatch-agent`) |
| `agents/*/extensions/**/*.ts` | Yes | Custom agent extensions |
| `dotpi` | Yes | CLI dispatcher (setup, create, list, link-skill, link-auth) |
| `commands/*.sh` | Yes | Subcommand scripts (sourced by dotpi) |
| `env.sh` | Yes | Shell environment (sourced from .zshrc/.bashrc) |
| `dispatch-agent` | Yes | Symlink target in bin/ (dispatches commands to agents) |
| `lib/dispatch/*.sh` | Yes | Focused launcher internals sourced by `dispatch-agent` |
| `docs/**/*.md` | Yes | MkDocs documentation |
| `agents/*/extensions/*` | **No** | Symlinks — edit `shared/extensions/` instead |
| `agents/*/skills/*` | **No** | Symlinks — edit `shared/skills/` instead |
| `agents/*/themes/*` | **No** | Symlinks — edit `shared/themes/` instead |
| `*/models.json` (in agent configs) | **No** | Symlink chain → `shared/models.json` → `~/.pi/agent/models.json` |
| `shared/models.json` | **No** | Symlink → `~/.pi/agent/models.json`. Edit the system file directly or via `dotpi setup`. |
| `shared/auth.json` | **No** | Symlink → `~/.pi/agent/auth.json`. Edit `~/.pi/agent/auth.json` directly. |
| `*/bin/` | **No** | Symlink — managed by pi runtime |
| `*/sessions/` | **No** | Runtime data — gitignored |
| `*/settings.json` (in agent configs) | **No** | Symlink chain → `shared/settings.json` → `~/.pi/agent/settings.json` |
| `*/auth.json` | **No** | Symlink chain → `shared/auth.json` → `~/.pi/agent/auth.json` |
| `REFERENCES/**` | **No** | Local-only sibling checkouts; gitignored. Cloned manually for agent context (see `REFERENCE-REPOS.md`). |
| `model-defaults` | Local | Per-machine global fallback model aliases. Created by `dotpi sync` or `dotpi model-defaults`, loaded at agent launch time. |
| `agents/*/.model`, `subagents/*/.model`, `agents/*/agents/*/.model` | Local | Per-agent raw `provider/model` overrides written by `/model-default`; gitignored. |
| `shared/settings.json` | **No** | Symlink → `~/.pi/agent/settings.json`. Edit the system file directly or use pi's settings UI. |
| `.exa.env`, `.tavily.env` | Local | Repo-root API keys for Exa / Tavily; convention `.service-name.env`. Gitignored. |
| `VERSION` | Yes | Bump on releases. Surfaced via `dotpi --version`. |
