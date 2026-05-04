# Agent Layout

This guide explains the files that make up a dot-pi agent configuration. It is the human-readable companion to the terse agent-facing notes in `AGENTS.md`.

Every directory under `agents/<name>/` is a complete `PI_CODING_AGENT_DIR` root. When you run an agent command such as `reader`, `web`, or `lm`, `dispatch-agent` sets `PI_CODING_AGENT_DIR` to that directory and launches `pi` with the files in that root.

For the terminal syntax shared by all top-level agent commands, see [Terminal Dispatch](terminal-dispatch.md).

There are two common shapes:

- A **standalone agent** is one pi config root with its own prompt, arguments, skills, and extensions.
- A **multi-agent system** (MAS) is an orchestrator pi config root that includes the `agent-orchestrator` extension and a nested `agents/` directory of subagent config roots.

For the deeper MAS behavior, see [Multi-Agent Systems](reference/multi-agent-systems.md). This page focuses on what each file is for.

## Mock MAS Layout

```text
agents/example-mas/
├── README.md
├── USAGE.md
├── SYSTEM.md
├── APPEND_SYSTEM.md
├── AGENT.md
├── pi-args
├── banner.txt
├── bootstrap.sh
├── auth.json -> ../../shared/auth.json
├── models.json -> ../../shared/models.json
├── settings.json -> ../../shared/settings.json
├── bin -> ../../shared/bin
├── sessions/
├── extensions/
│   ├── agent-orchestrator -> ../../../shared/extensions/agent-orchestrator
│   ├── run-finish-notify -> ../../../shared/extensions-common/run-finish-notify
│   ├── run-timer -> ../../../shared/extensions-common/run-timer
│   ├── startup-branding -> ../../../shared/extensions-common/startup-branding
│   ├── save -> ../../../shared/extensions-common/save
│   ├── say -> ../../../shared/extensions-common/say
│   └── model-default -> ../../../shared/extensions-common/model-default
├── prompts/
│   ├── help.md -> ../../../shared/prompts/help.md
│   └── research-and-write.md
├── skills/
│   └── tavily-search -> ../../../shared/skills/tavily-search
├── themes/
│   └── synthwave.json -> ../../../shared/themes/synthwave.json
└── agents/
    └── specialist/
        ├── README.md
        ├── SYSTEM.md
        ├── APPEND_SYSTEM.md
        ├── USAGE.md
        ├── pi-args
        ├── extensions/
        ├── prompts/
        ├── skills/
        ├── themes/
        └── sessions/
```

Most real agents do not contain every optional file shown above. The mock tree is intentionally complete so you can see where each supported artifact belongs.

## Root Files

### `README.md`

Human-facing overview: purpose, design notes, links, and context for people (and for LLMs browsing the repo). Orchestrator listings and tooling may surface short descriptions from here.

Created by `dotpi create` and `dotpi create-agent`. Edit whenever the agent’s story or non-CLI documentation should change.

### `USAGE.md`

**Launcher help** for the agent command: `dispatch-agent` prints this file on standard output for `<agent> help`, `<agent> usage`, `-h`, and `--help` when the file exists (plain text, no `glow`/`bat`). Use a **man-page style** layout (title line, `NAME`, `SYNOPSIS`, sections, indented body text).

At the **MAS or standalone root**, this is the CLI reference for the symlink command. Under **`agents/<mas>/agents/<sub>/`**, `USAGE.md` is instead the **subagent invocation contract** appended to the orchestrator prompt by `agent-orchestrator` (same filename, two roles by directory level).

Scaffolds create a starter **`USAGE.md`** at the root; subagent **`USAGE.md`** files are added when you create subagents.

### `SYSTEM.md`

The main system prompt loaded by pi from the agent config root.

In a MAS root, this is the orchestrator prompt: it defines the workflow, delegation policy, artifacts, and final answer style. In a standalone root, it defines the agent's role directly. In a subagent root, it defines that subagent's role and output contract.

Created by both scaffold commands. A subagent must contain either `SYSTEM.md` or `APPEND_SYSTEM.md` to be discovered by `agent-orchestrator`.

### `APPEND_SYSTEM.md`

Optional prompt text appended to pi's default system prompt. Use this when you want to preserve the upstream default prompt and add local instructions instead of replacing the prompt entirely.

This file is manually authored when needed. It can be used in top-level agents and subagents.

### `AGENT.md`

Optional legacy prompt/config file read by the `agent-prompt` extension. Its YAML frontmatter can set fields such as `tools` or `model`, and its markdown body is appended to the system prompt.

New scaffolds do not link `agent-prompt` by default. Use `SYSTEM.md`, `APPEND_SYSTEM.md`, and `pi-args` unless you specifically want the older frontmatter-driven behavior.

### `pi-args`

Default CLI flags for every launch of this agent root. `dispatch-agent` reads this file before invoking `pi`.

The file is plain text: one flag or flag group per line, with `#` comments ignored. Use it for tools, context-file behavior, prompt-template flags, session behavior, and model defaults.

Common examples:

```text
--tools read,find,ls,grep,subagent
--model $DEFAULT_AGENTIC_MODEL
--no-context-files
```

Model aliases come from repo-local `model-defaults` and optional agent-local `.model` overrides. If an expanded `--model` value is empty, `dispatch-agent` skips that flag so pi falls back to its own default. Thinking policy is either hardcoded in `pi-args` or omitted.

Use `--no-context-files` for agents that should not inherit repository guidance such as `AGENTS.md` from the current working directory. Coding agents may intentionally omit it.

!!! warning "`--tools` is an allowlist that gates extension tools"

    When `--tools` is present, **only the listed tool names are available** to the agent. This applies equally to built-in tools, extension-registered tools (`pi.registerTool()`), and SDK custom tools. If an extension registers a tool (e.g. `tavily_search`) but the name is not in the `--tools` list, the LLM will receive "Tool not found" when it tries to call it.

    To use extension tools with a restricted built-in set, name them explicitly:

    ```text
    --tools read,ls,bash,tavily_search
    ```

    Omitting `--tools` entirely enables all tools (built-in defaults plus all extension tools). Use `--no-builtin-tools` to suppress only the default built-ins (read, bash, edit, write) while keeping all extension tools enabled.

### `banner.txt`

Startup branding displayed by the `startup-branding` extension. The scaffold writes it when `figlet` is available; otherwise it is simply absent.

Edit this as ordinary text if you want the agent command to show different startup copy.

### `bootstrap.sh`

This sourced shell script prepares the launch environment before pi starts. If it contains a top-level `WORKSPACE_AGENT=1` line, the command runs in workspace mode. Instead of running in the current directory, `dispatch-agent` creates a dated workspace under:

```text
workspaces/<agent>/<YYYY-mm-dd-HHMMSS>/
```

```bash
WORKSPACE_AGENT=1
export WORKSPACE_AGENT

mkdir -p "$WORKSPACE_DIR/sources" "$WORKSPACE_DIR/drafts" "$WORKSPACE_DIR/sessions"
export OUTPUT_DIR="$WORKSPACE_DIR/drafts"
```

Because the script is sourced, exported variables persist into pi. Use it to create workspace directories, set env vars, initialize daemons, and run health checks. It runs on fresh launches, `resume`, and in-situ launches for agents that define it.

The launcher provides `DOT_PI_DIR`, `AGENT_NAME`, `AGENT_DIR`, `WORKSPACE_AGENT`, `WORKSPACE_DIR` for workspace agents, `DOTPI_BOOTSTRAP_PHASE` (`fresh`, `resume`, or `in-situ`), and `BOOTSTRAP_LOG`. Bootstrap stdout/stderr is captured in `BOOTSTRAP_LOG`; for workspace agents the default is `$WORKSPACE_DIR/bootstrap.log`.

If the workspace contains a `sessions/` directory, `dispatch-agent` passes `--session-dir <workspace>/sessions` so the orchestrator and subagents can keep their session logs with the workspace artifacts.

Legacy `workspace.env` and `workspace.conf` files are no longer used by current launchers. Put workspace setup in `bootstrap.sh`.

### `models.json`

Symlink to shared model provider configuration:

```text
agents/<name>/models.json -> ../../shared/models.json -> ~/.pi/agent/models.json
```

Created by the scaffold and repaired by `dotpi sync`. Do not edit the agent-level symlink target in place; manage model providers with `dotpi setup` or by editing the system pi config intentionally.

### `settings.json`

Symlink to shared pi settings:

```text
agents/<name>/settings.json -> ../../shared/settings.json
```

`dotpi sync` symlinks `shared/settings.json` from `~/.pi/agent/settings.json` if needed. The shared file is local machine configuration and is not tracked.

### `auth.json`

Symlink to the shared credential store:

```text
agents/<name>/auth.json -> ../../shared/auth.json
```

The canonical file is **`shared/auth.json`** (gitignored, symlinked from `~/.pi/agent/auth.json` by `dotpi sync`). pi reads credentials from each agent root via this symlink, so all top-level agents share one `auth.json`.

`dotpi sync` creates `shared/auth.json` if missing and links every `agents/<name>/auth.json` → `shared/auth.json`. Scaffolds (`dotpi create`, `dotpi create-agent`) create the symlink as well.

If you previously stored credentials as a **regular file** under `agents/<name>/auth.json`, merge those entries into `shared/auth.json` before running `dotpi sync`: **`ln -sf` replaces** a regular file with the symlink.

Use **`dotpi link-auth`** when an agent must point at a different file (another agent, `shared`, or an explicit path):

```bash
dotpi link-auth shared other-agent
dotpi link-auth lm recon
```

## Root Directories

### `extensions/`

TypeScript extensions loaded automatically by pi. Extensions can register tools, add lifecycle hooks, render TUI elements, or adjust prompts.

Top-level MAS and standalone roots link the standard bundle from `shared/extensions-common/`:

- `run-finish-notify`
- `run-timer`
- `startup-branding`
- `save`
- `say`

MAS scaffolds also link the specialized `agent-orchestrator` extension. Standalone scaffolds create a custom extension at `extensions/<agent-name>/index.ts`.

Bundle symlinks point through `shared/extensions-common/`, which itself points to implementations in `shared/extensions/`. Edit extension source in `shared/extensions/`, not through an agent-level symlink.

### `agents/`

MAS-only directory containing subagent config roots. Each subdirectory is itself a pi config root with its own prompts, args, skills, extensions, and session behavior.

The `agent-orchestrator` extension discovers subagents from this directory and from project-local `.pi/agents/` directories. A subagent is available when it has `SYSTEM.md` or `APPEND_SYSTEM.md`.

Standalone agents do not need this directory.

### `prompts/`

Prompt templates invoked inside pi with `/template-name`. Scaffolds link `prompts/help.md` to `shared/prompts/help.md`; you can add workflow-specific templates beside it.

Prompt templates are useful for stable workflows such as research-write-edit chains, fixed implementation/review loops, or repeatable report generation.

### `skills/`

Opt-in skill symlinks. Skills are markdown instruction bundles stored in `shared/skills/<skill>/SKILL.md` and linked per agent with:

```bash
dotpi link-skill <agent> <skill>
```

The scaffold creates an empty `skills/` directory. No shared skill is active for an agent until it is linked into that agent root.

#### Skill bootstraps

A skill directory may contain `scripts/bootstrap.sh`. When present, `dispatch-agent` sources it before pi starts — after the agent-level `bootstrap.sh` (if any) and in alphabetical order by skill name. Because the script is sourced, exported variables persist into pi and are available in every bash tool call.

Use this for environment setup that the skill's `SKILL.md` depends on: tool paths, state directories, daemon health checks. Skill bootstraps receive the same environment contract as `bootstrap.sh`: `DOT_PI_DIR`, `AGENT_NAME`, `AGENT_DIR`, `DOTPI_BOOTSTRAP_PHASE`, `WORKSPACE_AGENT`, optional `WORKSPACE_DIR`, and `BOOTSTRAP_LOG`. They should be idempotent and must not declare workspace mode. A non-zero exit stops the launch.

### `themes/`

Per-theme symlinks to `shared/themes/*.json`. The scaffold links available shared themes into each top-level agent root.

### `bin/`

Symlink to `shared/bin/`, where pi can store downloaded helper binaries such as `fd` and `rg`. This lets all agent configs share one binary cache.

This is different from the repo-level `bin/` directory. `dotpi sync` creates command symlinks such as `bin/reader -> ../dispatch-agent` so agent names can be run directly from the shell.

### `sessions/`

Runtime conversation history for non-workspace launches. Scaffolds create the directory, but its contents are runtime data and should not be treated as source.

Workspace agents usually store sessions under the workspace's own `sessions/` directory instead.

## Repo-Level Support Files

Some files affect agent behavior but do not live inside a specific `agents/<name>/` root.

### `agent-orchestrator.conf`

Optional dot-pi root config for limited local-provider concurrency. It is read by the `agent-orchestrator` extension when scheduling subagent work.

```ini
local=1
default=1
```

Subagents select models with `pi-args`; `agent-orchestrator` derives scheduling from the resolved model provider. See [Subagent Concurrency](reference/subagent-concurrency.md) for the full scheduling model.

### `local-providers.conf`

Optional dot-pi root config listing providers backed by limited local or self-hosted compute:

```text
lmstudio
```

Any provider not listed is treated as API-backed and unbounded. If this file is missing, `lmstudio` is still treated as local by default.

### `bin/<agent>`

Repo-level command symlinks generated by `dotpi sync`:

```text
bin/reader -> ../dispatch-agent
bin/web -> ../dispatch-agent
```

The symlink name determines which `agents/<name>/` config root `dispatch-agent` launches.

### `shared/extensions-common/`

Symlink bundle for standard top-level agent extensions. `dotpi create`, `dotpi create-agent`, and `dotpi sync` link each entry into top-level `agents/<name>/extensions/`.

### `shared/extensions-subagents/`

Symlink bundle for default subagent extensions. `dotpi sync` links each entry into discovered subagent roots under `agents/<mas>/agents/<subagent>/extensions/`.

Reusable subagents live canonically under `subagents/<name>/` and are symlinked into MAS roots, for example `agents/deepresearch/agents/scout -> ../../../subagents/scout`. In that case, `dotpi sync` wires `shared/extensions-subagents/` into the canonical `subagents/<name>/` directory. MAS-specific local subagents can be real directories under `agents/<mas>/agents/<subagent>/`.

### `model-defaults`

Required local repo-root file created by `dotpi sync` (with empty defaults) if missing. It provides fallback model aliases:

```sh
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
```

Configure it with `dotpi model-defaults`. Empty values are allowed. The `/model-default` command can write an agent-local `.model` file containing a single raw `provider/model` id for that specific agent.

## Subagent Roots

A subagent under `agents/<mas>/agents/<subagent>/` is a separate pi config root. It does not automatically inherit extensions, skills, prompts, or args from the parent MAS root.

Recommended subagent files:

- `SYSTEM.md` or `APPEND_SYSTEM.md`: required for discovery.
- `README.md`: short human-readable capability description; also used in orchestrator listings.
- `USAGE.md`: invocation contract appended to the orchestrator prompt.
- `pi-args`: subagent-specific tool, context-file, and skill flags.
Subagents can also have their own `skills/`, `prompts/`, `themes/`, `sessions/`, `models.json`, `settings.json`, and `auth.json` if needed. Keep the root minimal unless the subagent actually needs those capabilities.

## Standalone Agent Layout

A standalone agent is the same config-root concept without the MAS pieces:

```text
agents/example-standalone/
├── README.md
├── USAGE.md
├── SYSTEM.md
├── APPEND_SYSTEM.md
├── AGENT.md
├── pi-args
├── banner.txt
├── bootstrap.sh
├── auth.json -> ../../shared/auth.json
├── models.json -> ../../shared/models.json
├── settings.json -> ../../shared/settings.json
├── bin -> ../../shared/bin
├── sessions/
├── extensions/
│   ├── example-standalone/
│   │   └── index.ts
│   ├── run-finish-notify -> ../../../shared/extensions-common/run-finish-notify
│   ├── run-timer -> ../../../shared/extensions-common/run-timer
│   ├── startup-branding -> ../../../shared/extensions-common/startup-branding
│   ├── say -> ../../../shared/extensions-common/say
│   ├── save -> ../../../shared/extensions-common/save
│   └── model-default -> ../../../shared/extensions-common/model-default
├── prompts/
│   └── help.md -> ../../../shared/prompts/help.md
├── skills/
└── themes/
```

The main differences are:

- There is no `agent-orchestrator` extension.
- There is no nested `agents/` subagent pool.
- The custom extension under `extensions/<agent-name>/` is often the main behavior hook.
- `SYSTEM.md` addresses the user directly instead of coordinating subagents.

## Workspace Runtime Layout

Workspace mode creates runtime directories under `workspaces/`, not under `agents/`:

```text
workspaces/example-mas/2026-04-28-120000--named-run/
├── sources/
├── drafts/
├── sessions/
├── report.md
└── manifest.json
```

The exact artifact files are workflow-specific. For example, a research agent might write `sources/` and `report.md`, while a reader/OCR agent writes `pages/`, `reader-manifest.json`, `document.md`, and `summary.md`.

Workspace contents are runtime artifacts. They are useful for resuming and debugging, but they are not agent source.

## What To Edit

Usually edited by humans:

- `README.md`
- `USAGE.md` (root: launcher help; subagent: orchestrator contract)
- `SYSTEM.md`
- `APPEND_SYSTEM.md`
- `pi-args`
- `banner.txt`
- `bootstrap.sh`
- `prompts/*.md`
- `agents/*/README.md`
- `agents/*/SYSTEM.md`
- `agents/*/USAGE.md`
- `agents/*/pi-args`
- custom extension source under non-symlinked `extensions/<name>/`

Usually generated, symlinked, local, or runtime:

- `models.json`
- `settings.json`
- `bin/`
- shared extension, skill, and theme symlinks
- `auth.json` (symlink to `shared/auth.json`; edit the shared file)
- `sessions/`
- workspace directories under `workspaces/`

When in doubt, edit the canonical source: extension implementations in `shared/extensions/`, extension bundle membership in `shared/extensions-common/` or `shared/extensions-subagents/`, shared skills in `shared/skills/`, shared themes in `shared/themes/`, and agent-specific prompts or config in the owning `agents/<name>/` root.
