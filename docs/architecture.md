# Architecture

## What This Project Is

dot-pi is a dotfiles repository for the [pi coding agent](https://github.com/nichochar/pi-mono). It turns a bare pi installation into a full agent toolkit: multi-agent teams, web research, prompt templates, session archiving, workspace management, and self-diagnostic tooling.

The goal is a **self-improving agentic system**. Agent teams produce output. The retro team diagnoses what went wrong. A human feeds the diagnosis to a frontier model to implement fixes. The cycle repeats.

```
  Run agent team
        |
        v
  Produce output + session logs
        |
        v
  Run retro team (diagnose)
        |
        v
  Feed diagnosis to frontier model
        |
        v
  Improve prompts / workflow / config
        |
        v
  Run agent team again (better)
```

## Directory Structure

```
dot-pi/
  agents/                Agent definitions (.md with YAML frontmatter)
    teams.yaml           Team compositions
    newsroom-editor.md   Managing editor for the newsroom team
    desk-reporter.md     Generic desk reporter (parameterized per topic)
    ...
  docs/                  Documentation (you are here)
  extensions/            Pi extensions (TypeScript)
    orchestration/
      agent-team.ts      Grid-dashboard orchestrator (older, used by pteam)
      agent-team-2.ts    Inline-output orchestrator (used by pnews, pretro, pteam2)
    ui/
      theme-cycler.ts    Cycles through themes in themes/ directory
  prompts/               Prompt templates (available as /commands in interactive sessions)
    news-report.md       Kicks off a newsroom run via /news-report
    retro.md             Kicks off a retro analysis via /retro
  scripts/               Shell scripts for headless/scheduled runs
    newsroom-daily.sh    Daily briefing runner (cron-friendly)
    newsroom-weekly.sh   Weekly overview runner (cron-friendly)
  sessions/              Session archives for non-team aliases (pchat, pweb, pexplain)
  skills/                Skill files that teach agents how to use specific tools
    bowser/              Browser automation
    nak/                 Nostr Army Knife
    searxng/             SearXNG search API
  themes/                Color themes (.json) for the pi TUI
  workspaces/            Agent team outputs — per-team, per-run
    newsroom/
      topics/            Persistent topic configs and story index (shared across runs)
      2026-04-08_1430/   One run: session.jsonl, sessions/*.jsonl, output files
  reference/             Reference repos (gitignored) — pi-mono, pi-recipes, feynman
  pi-aliases             Shell aliases and functions — the main user entry point
  .env                   API keys (gitignored)
  mkdocs.yml             MkDocs Material config for GitHub Pages
```

## Shell Aliases (`pi-aliases`)

All pi commands are defined as shell functions in `pi-aliases`. This file is sourced from `~/.zshrc`.

### Non-team aliases

These run a single pi agent with a specific system prompt and tool set. Sessions are archived to `~/dot-pi/sessions/` via `--session-dir`.

| Alias | Purpose | Tools | Notable flags |
|-------|---------|-------|---------------|
| `pchat` | Conversational chatbot | `read,grep,find,ls` (read-only) | `--no-skills`, `--no-prompt-templates` |
| `pexplain` | Codebase analyst | `read,grep,find,ls` (read-only) | `--no-skills` |
| `pweb` | Web research via SearXNG | `read,bash` | Loads SearXNG skill file |

### Team aliases

These launch the `agent-team-2.ts` orchestration extension. The `AGENT_TEAM` env var selects the team. Sessions and output go to dedicated workspaces.

| Alias | Team | Session location | Workspace |
|-------|------|------------------|-----------|
| `pnews` | `newsroom` | `WORKSPACE/session.jsonl` | `~/dot-pi/workspaces/newsroom/$RUN_ID/` |
| `pretro` | `retro` | `WORKSPACE/session.jsonl` | `~/dot-pi/workspaces/retro/$RUN_ID/` |
| `pteam` | User-selected | `~/dot-pi/sessions/` | None |
| `pteam2` | User-selected | `~/dot-pi/sessions/` | None |

Key difference: `pnews` uses `--session "$WORKSPACE/session.jsonl"` to co-locate the dispatcher's session with the workspace. `pretro` also uses co-located sessions in its own workspace. Both `pnews` and `pretro` use `AGENT_WORKSPACE` — `pretro` additionally sets `RETRO_TARGET` to the workspace being analyzed.

### `pnews` alias in detail

```bash
pnews() {
  local RUN_ID=$(date +%Y-%m-%d_%H%M)
  local TEAM_DIR="$HOME/dot-pi/workspaces/newsroom"
  local WORKSPACE="$TEAM_DIR/$RUN_ID"
  mkdir -p "$WORKSPACE/stories" "$WORKSPACE/sources" "$WORKSPACE/sources/images" "$WORKSPACE/sessions" \
           "$TEAM_DIR/topics"
  export AGENT_TEAM="newsroom"
  export AGENT_WORKSPACE="$WORKSPACE"
  pi \
    --session "$WORKSPACE/session.jsonl" \
    -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
    -e "$HOME/dot-pi/extensions/ui/theme-cycler.ts" \
    --theme "$HOME/dot-pi/themes" \
    --prompt-template "$HOME/dot-pi/prompts" \
    "$@"

  # Update story index if the run produced one (structured workflows only)
  [ -f "$WORKSPACE/story-index-update.yaml" ] && \
    cp "$WORKSPACE/story-index-update.yaml" "$TEAM_DIR/topics/story-index.yaml"
}
```

This function does several things:

1. **Creates a timestamped workspace** (`YYYY-MM-DD_HHMM`) so multiple runs per day get separate directories.
2. **Pre-creates subdirectories** (`stories/`, `sources/`, `sources/images/`, `sessions/`) so agents can write immediately.
3. **Exports `AGENT_TEAM`** — `agent-team-2.ts` reads this to auto-select the team on startup.
4. **Exports `AGENT_WORKSPACE`** — `agent-team-2.ts` reads this for two purposes:
   - Setting the sub-agent session directory to `$WORKSPACE/sessions/`
   - Injecting the workspace path into the dispatcher's system prompt
5. **Uses `--session`** (not `--session-dir`) to write the dispatcher's session file directly into the workspace root.
6. **Loads prompt templates** from `prompts/`, making `/news-report` and `/wire` available as commands.
7. **Post-run story index hook** — after `pi` exits, copies `story-index-update.yaml` (if it exists) back to the team's `topics/story-index.yaml` at the workspace root. This only fires after structured workflows that produce the update file. Ad-hoc conversations do not affect the story index.

### How Humans Use `pnews`

Three use cases, one entry point. The extension always injects saved topics and the story index as context — the user and prompt templates control what happens.

**Use Case 1: Ad-hoc exploration.** The user opens `pnews` and talks to the editor about whatever interests them, or provides an initial query (`pnews "tell me about zoning rules for ADUs"`). No structured workflow runs. The editor follows the user's lead, dispatching `desk-reporter` as needed. No story index update occurs — global memory is untouched.

**Use Case 2: Monitored topic updates.** The user triggers a structured workflow against saved topics: `/wire` for a quick scan, `/news-report` for a full six-phase briefing. Headless scripts (`newsroom-daily.sh`, `newsroom-weekly.sh`) pass equivalent prompts non-interactively. These workflows produce `story-index-update.yaml`, which is copied back to the team's `topics/story-index.yaml` by the post-run hook.

**Use Case 3: Topic management.** The user manages saved topics through conversation ("show my topics", "add a topic about bitcoin", "disable the fashion topic"). The editor reads topic info from its system prompt and dispatches `desk-reporter` to create/modify/delete YAML files in `~/dot-pi/workspaces/newsroom/topics/`.

### `pnews` vs headless scripts

Both run the newsroom team. They share the same workspace setup, env vars, extension loading, and post-run story index hook. The differences:

| Aspect | `pnews` (interactive) | `newsroom-daily.sh` / `newsroom-weekly.sh` |
|--------|----------------------|----------------------------------------------|
| Mode | Interactive TUI | `pi -p` (non-interactive, stdout) |
| Prompt delivery | User types `/news-report`, `/wire`, or free-form | Full prompt inlined with shell variable expansion |
| Prompt templates | Loaded via `--prompt-template` | Disabled via `--no-prompt-templates` |
| Skills | Loaded (default) | Disabled via `--no-skills` |
| UI | Theme cycler, footer, status bar | No extensions beyond orchestration |
| Use case | Human-in-the-loop, ad-hoc, testing | Cron jobs, scheduled unattended runs |

The main duplication risk is the prompt text: `prompts/news-report.md` for interactive mode, and the inlined string in the headless scripts for unattended mode. Both describe the same workflow. Changes must be reflected in both places.

## How Agent Teams Work

### Agent Definitions

Each agent is a markdown file in `agents/` with YAML frontmatter:

```markdown
---
name: desk-reporter
description: Generic desk reporter — scans any topic and writes sourced stories
tools: read,bash,write
role: lead
---
You are a desk reporter in an automated newsroom...
```

- **`name`** — identifier used for dispatch (`dispatch_agent("desk-reporter", ...)`). Case-insensitive.
- **`description`** — shown in the agent catalog injected into the dispatcher's system prompt.
- **`tools`** — comma-separated list of pi tools the agent gets when dispatched as a sub-agent. **Important:** these tools only apply when the agent runs as a sub-agent. When the agent is the top-level dispatcher, `agent-team-2.ts` overrides its tools to `["dispatch_agent"]` only (see below).
- **`model`** (optional) — a `provider/model-id` string that overrides the dispatcher's model for this agent. If omitted, the agent inherits the dispatcher's model. Used by `newsroom-vlm` to run on `lmstudio/qwen3.5-122b-a10b` (a vision-capable model) while other agents use the stronger text-only model.
- **`role`** (optional) — one of `lead` or omitted (defaults to worker). Leads are spawned with the orchestration extension loaded, giving them `dispatch_agent` alongside their own tools. Workers get only their frontmatter tools. See **Three-Tier Dispatch Model** below.
- **Body** — everything after the frontmatter becomes the agent's system prompt, passed via `--append-system-prompt`.

### Team Composition

Teams are defined in `agents/teams.yaml`:

```yaml
newsroom:
  - newsroom-editor        # orchestrator (implicit: first in list)
  - desk-reporter          # role: lead — generic, dispatched per topic
  - newsroom-scraper       # worker — fetches, cleans, writes source files
  - newsroom-researcher    # worker — deep investigation
  - newsroom-vlm           # worker — image/PDF processing (vision model)
  - newsroom-fact-checker   # worker — verification
  - newsroom-copy-editor   # worker — final assembly

retro:
  - retro-editor
  - retro-session-analyst
  - retro-output-reviewer
```

The first agent in the list becomes the dispatcher (orchestrator). Agents with `role: lead` in their frontmatter get dispatch capabilities alongside their own tools. All others are workers.

### The Orchestrator Extension (`agent-team-2.ts`)

This is the core orchestration engine. Understanding its behavior is critical for diagnosing agent runs and writing effective prompts.

#### Startup sequence (`session_start` hook)

1. Scans `agents/*.md` from both the working directory and `~/dot-pi/agents/` for agent definitions.
2. Reads `teams.yaml` from both locations (working directory takes precedence).
3. Auto-selects the team specified by `AGENT_TEAM` env var, or the first team if unset.
4. For orchestrators only, calls `pi.setActiveTools(["dispatch_agent"])` — **this overrides whatever tools the top-level agent's frontmatter specifies.** The dispatcher only gets `dispatch_agent`. No `bash`, no `read`, no `write`. Leads skip this step and keep their frontmatter tools.

#### System prompt injection (`before_agent_start` hook)

Before the dispatcher's first turn, the extension replaces the system prompt with:

1. A preamble explaining the dispatcher role ("You are a dispatcher agent...")
2. The active team name and member list
3. **The workspace path** (if `AGENT_WORKSPACE` is set) — injected as a code block so the dispatcher knows where agents should write output
4. Rules ("NEVER try to read, write, or execute code directly")
5. An agent catalog with each sub-agent's name, description, and tools

The dispatcher's original system prompt (from its `.md` file's body) is **completely replaced** by this generated prompt. The `.md` body for dispatcher agents (like `newsroom-editor.md`) is only used when that agent is dispatched as a sub-agent by something else.

#### Sub-agent dispatch (`dispatch_agent` tool)

When the dispatcher calls `dispatch_agent(agent, task)`:

1. The extension spawns a new `pi -p` process (non-interactive, JSON output mode).
2. The agent's system prompt (`.md` body) is written to a **temp file** and passed via `--append-system-prompt <path>`. This avoids OS argv length limits for agents with long prompts. The temp file is cleaned up when the process exits.
3. The sub-agent gets:
   - `--tools` from the agent definition's frontmatter
   - `--append-system-prompt` pointing to the temp file containing the agent's `.md` body
   - `--model` from the agent's frontmatter `model` field if set, otherwise the dispatcher's current model
   - `--session` pointing to `$WORKSPACE/sessions/<agent-name>_<N>.jsonl` (see **Session File Layout** below)
   - `--thinking off`
   - The `task` string as the user message
4. The sub-agent's output streams inline in the TUI.
5. The sub-agent's **text output is truncated to 8KB** before being returned to the dispatcher. This is critical: agents must write full output to disk and return brief summaries. If an agent returns a 50KB report as text, the dispatcher only sees the first 8KB.
6. The `AbortSignal` from the tool execution is wired to the child process. If the user cancels, the child receives `SIGTERM` (with a 5-second fallback to `SIGKILL`), preventing orphan processes.

#### Session File Layout

A workspace-based team run produces the following session files:

```
workspaces/newsroom/2026-04-08_1430/
  session.jsonl                                  # orchestrator's pi session
  sessions/
    desk-reporter_1.jsonl                        # 1st dispatch of desk-reporter (e.g. geopolitics scan)
    desk-reporter_2.jsonl                        # 2nd dispatch (e.g. scitech scan)
    desk-reporter_3.jsonl                        # 3rd dispatch (e.g. geopolitics investigate)
    desk-reporter.newsroom-scraper_1.jsonl       # newsroom-scraper dispatched BY desk-reporter
    desk-reporter.newsroom-researcher_1.jsonl    # newsroom-researcher dispatched BY desk-reporter
```

**Naming convention:** `[<dispatcher>.]<agent-key>_<N>.jsonl`

- `session.jsonl` at the workspace root is the **orchestrator's own pi session**. It records the orchestrator's `dispatch_agent` tool calls and their returned summaries. This file is set up by the shell alias via `--session "$WORKSPACE/session.jsonl"`.
- Sub-agent sessions use the `.jsonl` extension to match pi's native convention. The numeric suffix `_N` is the per-agent dispatch count (1-indexed). Each dispatch creates a **separate file** -- there is no cross-dispatch continuity or session resumption.
- For three-tier dispatch, the `AGENT_DISPATCHER` env var is set to the lead's agent key. Workers dispatched by a lead get the lead's name as a prefix (e.g., `desk-reporter.newsroom-scraper_1.jsonl`). This prevents collisions when multiple leads dispatch the same worker concurrently.

All session files are JSONL (one JSON object per line). The first line is always a `type: "session"` header with the session UUID and timestamp.

### Three-Tier Dispatch Model

The system uses a three-tier hierarchy: **orchestrator → leads → workers**.

```
User prompt (or /news-report template)
    |
    v
Tier 1: Orchestrator (editor) — has ONLY dispatch_agent
    |  - System prompt: generated by agent-team-2.ts (replaces .md body)
    |  - Knows: team members, workspace path, rules
    |  - Cannot: read files, run bash, write files
    |
    |--- dispatch_agent("desk-reporter", "INVESTIGATE MODE. Topic: Geopolitics...")
    |       |
    |       v
    |    Tier 2: Lead — has frontmatter tools + dispatch_agent
    |       |  - Spawned WITH agent-team-2.ts extension loaded
    |       |  - System prompt: .md body KEPT, team roster appended
    |       |  - Can: read, bash, write AND dispatch workers
    |       |
    |       |--- dispatch_agent("newsroom-scraper", "Fetch URL. ...")
    |       |       |
    |       |       v
    |       |    Tier 3: Worker — frontmatter tools only
    |       |       Spawned with --no-extensions
    |       |       Fetches, sanitizes, writes source file
    |       |
    |       v
    |    Lead writes story file referencing confirmed sources
    |
    v
Orchestrator reviews summaries, dispatches next phase
```

#### Role behaviors

| Role | Tools | System prompt | Spawned with |
|------|-------|---------------|-------------|
| **Orchestrator** (first in team list) | `dispatch_agent` only | Replaced by extension | Extension (top-level process) |
| **Lead** (`role: lead` in frontmatter) | Frontmatter tools + `dispatch_agent` | `.md` body preserved, team roster appended | `-e agent-team-2.ts`, `AGENT_ROLE=lead` |
| **Worker** (default) | Frontmatter tools only | `.md` body via `--append-system-prompt` | `--no-extensions` |

#### How role dispatch works in `agent-team-2.ts`

- **Orchestrator:** `session_start` calls `pi.setActiveTools(["dispatch_agent"])`, stripping all other tools. `before_agent_start` replaces the system prompt.
- **Lead:** Spawned with `-e agent-team-2.ts` instead of `--no-extensions`. Four env vars are forwarded to the child process: `AGENT_ROLE=lead`, `AGENT_TEAM` (current team name), `AGENT_WORKSPACE` (if set), and `AGENT_DISPATCHER` (the lead's own agent key, used to prefix worker session filenames). The extension fires again inside the lead's process. Because `AGENT_ROLE=lead`, `session_start` skips `setActiveTools` — the lead keeps its frontmatter tools AND gets `dispatch_agent` registered by the extension. `before_agent_start` appends the team roster to the lead's own system prompt rather than replacing it.
- **Worker:** Spawned with `--no-extensions`. Gets only frontmatter tools. Cannot dispatch.

#### Environment variables for dispatch

| Variable | Set by | Read by | Purpose |
|----------|--------|---------|---------|
| `AGENT_TEAM` | Shell alias / parent process | `session_start` | Selects which team to activate |
| `AGENT_WORKSPACE` | Shell alias / parent process | `loadAgents()`, `before_agent_start` | Sets session dir and workspace path in system prompt |
| `AGENT_ROLE` | Parent `dispatchAgent()` | `session_start`, `before_agent_start` | Controls tool restriction and prompt handling |
| `AGENT_DISPATCHER` | Parent `dispatchAgent()` (for leads) | `dispatchAgent()` | Prefixes sub-agent session filenames to avoid collisions in three-tier dispatch |
| `RETRO_TARGET` | `pretro` alias | `before_agent_start` | Workspace path for retro analysis (retro team only) |

For leads, `AGENT_TEAM`, `AGENT_WORKSPACE`, and `AGENT_DISPATCHER` are forwarded from the parent process so the lead's extension instance can load the same team, write sessions to the same workspace, and namespace its workers' session files.

### Constraints

- **Two levels of dispatch maximum.** Orchestrators dispatch leads and workers. Leads dispatch workers. Workers cannot dispatch.
- **Concurrent dispatch allowed.** The same agent can be dispatched multiple times concurrently (each gets a unique session file via the `_N` suffix). The editor's prompt instructs conservative batching (1-2 topics at a time) to manage inference load, but the extension does not enforce a limit.
- **8KB return truncation.** Sub-agent text output returned to the dispatcher is capped at 8KB. Write full output to disk.
- **No shared memory.** Agents communicate only through the file system. There is no message passing between sub-agents.
- **Orchestrator has no filesystem tools.** The orchestrator cannot `read`, `write`, `bash`, or `edit`. It can only `dispatch_agent`. This is enforced by `pi.setActiveTools(["dispatch_agent"])` at startup.
- **System prompt handling differs by role.** For orchestrators, the extension replaces the system prompt entirely. For leads, the extension appends the team roster to the existing system prompt. For workers, the `.md` body is passed via `--append-system-prompt`.
- **Per-agent model override.** Agents with a `model` field in their frontmatter use that model instead of inheriting the dispatcher's. Agents without the field inherit as before. This enables mixing model types (e.g., a vision model for media processing alongside a stronger text model for reporting).

## Session Format

Pi stores conversation history as JSONL (one JSON object per line). Each line has a `type` field:

| Type | Description |
|------|-------------|
| `session` | Run metadata — id, working directory, timestamp |
| `model_change` | Model and provider info |
| `thinking_level_change` | Thinking mode setting |
| `message` (role: user) | Prompts and dispatch task descriptions |
| `message` (role: assistant) | Agent decisions, tool calls, token usage in `usage` field |
| `message` (role: toolResult) | Tool output, `isError` flag, `toolName` |

Assistant messages include a `usage` object with `input`, `output`, and `cacheRead` token counts. Tool results can be very large: `dispatch_agent` results embed the entire sub-agent transcript as JSON, making individual lines up to 200KB.

### Session file locations

| Run type | Main session | Sub-agent sessions |
|----------|-------------|-------------------|
| Team with workspace (`pnews`, `pretro`) | `WORKSPACE/session.jsonl` | `WORKSPACE/sessions/<agent>_<N>.jsonl` |
| Team without workspace (`pteam2`) | `~/dot-pi/sessions/` | `.pi/agent-sessions/<agent>_<N>.jsonl` |
| Non-team (`pchat`, `pweb`) | `~/dot-pi/sessions/` | N/A |

For workspace-based team runs, everything lives together: session files, sub-agent sessions, and output files. One directory = one run = everything needed for retro analysis. Each dispatch creates a separate session file (no cross-dispatch continuation), and three-tier dispatches use a dispatcher prefix to avoid collisions (see **Session File Layout** above).

## Prompt Templates

Prompt templates live in `prompts/` as markdown files with frontmatter:

```markdown
---
description: Produce a daily news briefing via the newsroom agent team
---
Produce today's news briefing. $@
...
```

When loaded via `--prompt-template`, each template becomes a `/command` in interactive sessions (e.g., `/news-report`). The `$@` token is replaced by whatever the user types after the command name.

Templates are instructions for the dispatcher agent, not for sub-agents. They describe the workflow the dispatcher should execute using `dispatch_agent`.

Available templates:

| Template | Purpose | Story index affected? |
|----------|---------|----------------------|
| `/news-report` | Full six-phase briefing against saved topics | Yes — copy editor writes `story-index-update.yaml` |
| `/wire` | Scan-only: produce wire files for saved topics, return editorial summary | Yes — lighter update, new candidates only |
| `/retro` | Run retro analysis against a workspace | No |

Templates use placeholder tokens like `[DATE]` and `[WORKSPACE]` that the dispatcher agent is expected to resolve from its system prompt context (the workspace path is injected by `agent-team-2.ts`, the date is usually mentioned in the task or system prompt).

In the headless scripts (`newsroom-daily.sh`, `newsroom-weekly.sh`), these placeholders are replaced by shell variable expansion since the prompt is inlined directly.

## Topic System

The newsroom uses a data-driven topic system. Instead of hardcoded desk agents per beat, topics are defined as YAML files in `workspaces/newsroom/topics/` and a single generic `desk-reporter` agent handles all of them, parameterized per dispatch. Co-locating topics with the team's workspace directory keeps all team-specific persistent data portable and self-contained.

### Topic Definitions (`workspaces/newsroom/topics/*.yaml`)

Each YAML file defines one topic the newsroom should cover:

```yaml
name: Geopolitics & Foreign Policy
slug: geopolitics
active: true
priority: high        # high = every run, medium = rotating, low = weekly
scan_queries:
  - "US+foreign+policy"
  - "sanctions+diplomacy+international"
categories: [news]
time_range: month
follow:
  - "US-Iran ceasefire developments"
notes: |
  Prefer primary sources: White House releases, State Dept briefings...
```

Key fields:
- `active: false` disables a topic without deleting it
- `priority` controls scheduling: `high` topics scan every run, `medium` rotate, `low` only in weekly mode
- `scan_queries` are user-crafted search terms — handles niche/local interests where generic keywords would miss
- `follow` lists ongoing storylines the desk should check for updates
- `categories` and `time_range` map to SearXNG API params

### Story Index (`workspaces/newsroom/topics/story-index.yaml`)

A persistent file tracking stories across runs for temporal continuity:

```yaml
- slug: us-iran-ceasefire
  topic: geopolitics
  status: developing     # developing | concluded | dormant
  first_covered: 2026-04-07
  last_covered: 2026-04-09
  bluf: "Pakistan-mediated talks resume after Hormuz closure tests ceasefire"
  timeline:
    - date: 2026-04-07
      bluf: "Ceasefire announced, contingent on Hormuz reopening"
    - date: 2026-04-08
      bluf: "Iran closes Hormuz, ceasefire tested; Pakistan mediating"
```

The `timeline` is an append-only log — each structured run adds at most one entry per story. The top-level `bluf` always reflects the most recent update. Stories without updates for 7+ days are marked `dormant` by the weekly workflow.

**Lifecycle:**
1. `agent-team-2.ts` reads `workspaces/newsroom/topics/story-index.yaml` at startup and injects developing stories into the editor's system prompt
2. Editor tells `desk-reporter` about developing stories, including last known BLUF and date
3. Copy editor writes `story-index-update.yaml` to the workspace as its final step
4. `pnews` shell function copies the update back to `workspaces/newsroom/topics/story-index.yaml` after `pi` exits — but only if the file exists (structured workflows produce it, ad-hoc conversations do not)

### Topic Injection

The `agent-team-2.ts` extension loads all active topics and the story index at startup (`loadTopics()`), deriving the topics directory from the parent of `AGENT_WORKSPACE`. For orchestrator agents, these are injected into the system prompt as `## Saved Topics` and `## Developing Stories` sections. This gives the editor full context regardless of invocation mode — the editor decides what to act on based on the user's message or prompt template.

### Generic Desk Reporter

The `desk-reporter` agent is topic-agnostic. Its system prompt contains SCAN MODE and INVESTIGATE MODE instructions with placeholders. The editor composes topic-specific dispatch tasks:

```
SCAN MODE. Today is 2026-04-08. Topic: Geopolitics & Foreign Policy (slug: geopolitics).
Search queries: US+foreign+policy, sanctions+diplomacy, ...
Categories: news. Time range: month.
Developing stories to check for updates:
  - us-iran-ceasefire (last covered 2026-04-08): "..."
Write your wire to /path/workspace/wire-geopolitics.md
```

This replaces the old model of having separate `desk-geopolitics.md` and `desk-scitech.md` agents. Adding a new topic requires only creating a new YAML file in `workspaces/newsroom/topics/` — no code or agent changes needed.

## Output Formats

Agent teams produce structured artifacts with YAML frontmatter and (where applicable) BLUF structure. The newsroom team's formats are documented in [docs/formats.md](formats.md) and include:

- **Wire files** — lightweight scan results with freshness and sourcing potential ratings
- **Source files** — sanitized web sources with metadata, overview, key quotations, and media flags
- **Story files** — BLUF-structured per-story reports with frontmatter and source lists
- **Final reports** — BLUF-structured briefings with a consolidated source index

Format templates are embedded inline in each agent's prompt so agents don't need to read external files. The `docs/formats.md` file is the canonical reference for humans and frontier model sessions.

All agents that fetch web content include a prompt injection defense warning in their system prompt. Source files include a `content_quality` field and a prompt injection risk note.

## The Self-Improvement Loop

### 1. Run

An agent team runs and produces output. The main session JSONL is co-located with the workspace (for workspace-based teams like newsroom). Sub-agent sessions go to `WORKSPACE/sessions/`. All output files (reports, drafts, research) also go to the workspace.

### 2. Diagnose

The retro team (`pretro`) parses session JSONL files to trace agent trajectories, find errors, detect loops, and identify pathological patterns. It produces a lean diagnosis report (`retro.md`) that summarizes what happened and what went wrong.

The retro team is deliberately run on cheap/free models. Its job is to digest hundreds of KB of logs into a concise report, saving expensive frontier model tokens.

### 3. Fix

The user takes the retro report to a frontier model (Cursor, Claude, etc.) and says "implement these fixes." The frontier model has the full codebase context and can modify agent prompts, agent definitions, workflow configuration, the orchestration extension, or the alias setup.

### 4. Repeat

The improved system runs again. The retro team catches remaining issues. This docs directory (`docs/`) is part of the loop — it should be kept accurate so that frontier model sessions have correct context about how the system works.

## Limitations

### Model constraints

The system is designed to run on locally-hosted or free-tier non-frontier models (e.g., `qwen/qwen3-coder-next` via PlebChat, `gemini-3-flash-preview` via OpenRouter). This means:

- **Smaller context windows.** Agents can overflow if given too much data in a single dispatch. The phased architecture (scan then investigate) and write-to-disk discipline mitigate this.
- **Weaker instruction following.** Non-frontier models sometimes ignore specific instructions (e.g., using `time_range=day` when told to use `time_range=month`). The retro team catches these compliance failures.
- **No parallel tool calls.** Some models can't issue multiple tool calls in a single turn, so dispatching multiple topics may actually be sequential.
- **Occasional hallucination.** Cheaper models are more prone to fabricating tool arguments or misunderstanding task descriptions.

### Orchestration constraints

- **Two levels of dispatch.** The orchestrator dispatches leads and workers. Leads (with `role: lead`) can dispatch workers beneath them. Workers cannot dispatch. A desk lead needing source files dispatches `newsroom-scraper` directly rather than flagging the need for the orchestrator to handle.
- **System prompt handling.** The orchestrator's `.md` body is replaced by the extension at top level. Lead agents keep their `.md` body and get the team roster appended. Worker agents get their `.md` body via `--append-system-prompt`.
- **No cross-dispatch memory.** Each dispatch creates a fresh session file. The agent does not retain memory of prior dispatches within the same run. If an agent needs context from a prior dispatch, the orchestrator must include it in the task description.

### Infrastructure requirements

- **SearXNG** must be running locally at `http://localhost:8080` for web research.
- **Pi** must be installed and available as `pi` on the PATH.
- **API keys** must be configured in `~/dot-pi/.env`.

### Known gaps

- **Nostr publishing.** The `nak` skill exists but the automated publish-to-Nostr pipeline is not yet wired into the newsroom workflow.
- **Scheduled runs.** `scripts/newsroom-daily.sh` and `newsroom-weekly.sh` are ready for cron but have not been tested in a cron environment.
- **Cross-team retro.** The retro team can diagnose a single team's run but cannot compare across days or teams to identify longitudinal trends.
- **PDF parsing.** The VLM agent (`newsroom-vlm`) can attempt PDF text extraction, but results vary depending on PDF structure. Complex layouts, scanned-image PDFs, and encrypted documents may fail.
- **Image processing.** The VLM agent can describe images but cannot modify, crop, or resize them. Image descriptions are text-only.
- **Prompt template variables.** Template placeholders like `[DATE]` and `[WORKSPACE]` are not automatically expanded by pi. The dispatcher must infer their values from context. In the headless script, shell expansion handles this. In interactive mode, the dispatcher gets the workspace from its system prompt (injected by the extension) and the date from the task or its own knowledge.
