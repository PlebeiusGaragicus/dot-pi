# Architecture

## What This Project Is

dot-pi is a dotfiles repository for the [pi coding agent](https://github.com/nichochar/pi-mono). It turns a bare pi installation into a full agent toolkit: multi-agent teams, web research, prompt templates, session archiving, workspace management, and self-diagnostic tooling.

The goal is a **self-improving agentic system**. Agent teams produce output. The retro team diagnoses what went wrong. The user feeds the diagnosis to a frontier model to implement fixes. The cycle repeats, and the system gets better with each iteration.

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
  agents/              Agent definitions (.md with YAML frontmatter)
    teams.yaml          Team compositions
    newsroom-editor.md  Example agent definition
    ...
  docs/                 Documentation (you are here)
  extensions/           Pi extensions (TypeScript)
    orchestration/      Multi-agent orchestrators
      agent-team.ts     Grid-dashboard orchestrator
      agent-team-2.ts   Inline-output orchestrator (used by newsroom, retro)
    ui/
      theme-cycler.ts   Theme rotation extension
  prompts/              Prompt templates (available as /commands)
    news-report.md      Kicks off a newsroom run
    retro.md            Kicks off a retro analysis
  scripts/              Shell scripts for headless/scheduled runs
    newsroom.sh         Cron-friendly newsroom runner
  sessions/             Session archives (.jsonl transcripts)
  skills/               Skill files for teaching agents specific tools
    bowser/             Browser automation
    nak/                Nostr Army Knife
    searxng/            SearXNG search API
  themes/               Color themes for the pi TUI
  workspaces/           Agent team outputs (per-team, per-date)
    newsroom/
      2026-04-08/       One run's complete output
  reference/            Reference repos (gitignored)
  pi-aliases            Shell aliases — the main entry point
  .env                  API keys (gitignored)
```

## How Agent Teams Work

### Agent Definitions

Each agent is a markdown file in `agents/` with YAML frontmatter:

```markdown
---
name: desk-geopolitics
description: Beat reporter — geopolitics, US foreign policy
tools: read,bash,write
---
You are a geopolitics desk reporter...
```

The `tools` field controls which pi tools the agent can use. The body after the frontmatter becomes the agent's system prompt.

### Team Composition

Teams are defined in `agents/teams.yaml`:

```yaml
newsroom:
  - newsroom-editor
  - desk-geopolitics
  - desk-scitech
  - newsroom-researcher
  - newsroom-fact-checker
  - newsroom-copy-editor

retro:
  - retro-editor
  - retro-session-analyst
  - retro-output-reviewer
```

### The Orchestrator Extension

`agent-team-2.ts` is the orchestration engine. It:

1. Loads agent definitions from `agents/*.md`
2. Reads team compositions from `teams.yaml`
3. Gives the primary agent (first in the team list) a `dispatch_agent` tool
4. Restricts the primary agent to ONLY `dispatch_agent` (no `bash`, `read`, etc.)
5. Spawns sub-agents as separate `pi -p` processes with their own tools and context
6. Streams sub-agent output inline in the chat
7. Returns the sub-agent's text output to the dispatcher (truncated to 8KB)

The `AGENT_TEAM` environment variable auto-selects which team to activate on startup. The `AGENT_WORKSPACE` variable is injected into the dispatcher's system prompt so it knows where to write files.

### Dispatch Flow

```
User prompt
    |
    v
Dispatcher (editor) — has only dispatch_agent tool
    |
    |--- dispatch_agent("desk-geopolitics", "scan headlines...")
    |       |
    |       v
    |    pi -p --tools read,bash,write --append-system-prompt "..."  "task..."
    |       |
    |       v
    |    Sub-agent runs independently, writes files, returns text
    |       |
    |       v
    |    Output truncated to 8KB, returned to dispatcher
    |
    |--- dispatch_agent("desk-scitech", "scan headlines...")
    |       ...
    v
Dispatcher reads summaries, makes decisions, dispatches next phase
```

## The Self-Improvement Loop

### 1. Run

An agent team runs and produces output. The main session is archived to `sessions/` as a JSONL file. Sub-agent sessions are stored in the workspace's `sessions/` directory. All output files (reports, drafts, research) go to the workspace.

### 2. Diagnose

The retro team parses the session JSONL files to trace agent trajectories, find errors, detect loops, and identify pathological patterns. It produces a lean diagnosis report (`retro.md`) that summarizes what happened and what went wrong.

### 3. Fix

The user takes the diagnosis to a frontier model (Cursor, Claude, etc.) and says "implement these fixes." The frontier model has the full codebase context and can modify agent prompts, workflow configuration, or the orchestration extension.

### 4. Repeat

The improved system runs again. Better prompts produce better output. The retro team catches remaining issues. The cycle continues.

This architecture deliberately separates **cheap diagnosis** (free pi agents parsing logs) from **expensive implementation** (frontier models editing code). The retro team's output is small enough to paste into a chat session without blowing up context.

## Session Format

Pi stores conversation history as JSONL (one JSON object per line). Each line has a `type` field:

| Type | Description |
|------|-------------|
| `session` | Run metadata (id, working directory, timestamp) |
| `model_change` | Model and provider info |
| `thinking_level_change` | Thinking mode setting |
| `message` (role: user) | Prompts and dispatch task descriptions |
| `message` (role: assistant) | Agent decisions, tool calls, token usage |
| `message` (role: toolResult) | Tool output, `isError` flag |

Assistant messages include a `usage` object with token counts (`input`, `output`, `cacheRead`) and cost. Tool results can be very large -- `dispatch_agent` results embed the entire sub-agent transcript.

See [docs/retro.md](retro.md) for detailed JSONL parsing techniques.

## Aliases

All pi commands are defined as shell functions in `pi-aliases`:

| Alias | Purpose | Key flags |
|-------|---------|-----------|
| `pchat` | Conversational chatbot | Read-only tools, custom system prompt |
| `pexplain` | Codebase analyst | Read-only tools |
| `pweb` | Web research via SearXNG | SearXNG skill, `bash,read,write` tools |
| `pnews` | Newsroom team | `agent-team-2.ts`, `AGENT_TEAM=newsroom` |
| `pretro` | Retro team | `agent-team-2.ts`, `AGENT_TEAM=retro` |
| `pteam` | Generic team (grid UI) | `agent-team.ts` |
| `pteam2` | Generic team (inline UI) | `agent-team-2.ts` |

All aliases source `~/.env` for API keys and archive sessions to `~/dot-pi/sessions/`.

## Limitations

### Model constraints

The system is designed to run on locally-hosted or free-tier non-frontier models (e.g., `qwen/qwen3-coder-next` via PlebChat). This means:

- **Smaller context windows.** Agents can overflow if given too much data in a single dispatch. The phased architecture (scan then investigate) and write-to-disk discipline mitigate this.
- **Weaker instruction following.** Non-frontier models sometimes ignore specific instructions (e.g., using `time_range=day` when told to use `time_range=month`). The retro team catches these compliance failures.
- **No parallel tool calls.** Some models can't issue multiple tool calls in a single turn, so dispatching "both desks in parallel" may actually be sequential.
- **Occasional hallucination.** Cheaper models are more prone to fabricating tool arguments or misunderstanding task descriptions.

### Orchestration constraints

- **One level of dispatch.** `agent-team-2.ts` only supports the top-level agent dispatching sub-agents. Sub-agents cannot dispatch other agents through the extension.
- **No parallel dispatch of the same agent.** An agent must finish before it can be dispatched again. Different agents can run concurrently (if the model issues multiple tool calls).
- **8KB return truncation.** Sub-agent text output is truncated to 8KB when returned to the dispatcher. Agents should write full output to disk and return brief summaries.
- **No shared memory.** Agents communicate only through the file system. There is no shared context or message passing between sub-agents.

### Infrastructure requirements

- **SearXNG** must be running locally at `http://localhost:8080` for web research.
- **Pi** must be installed and available as `pi` on the PATH.
- **API keys** must be configured in `~/.env` (or `~/dot-pi/.env`).

### What doesn't work yet

- **Nostr publishing.** The `nak` skill exists but the automated publish-to-Nostr pipeline is not yet wired into the newsroom workflow.
- **Scheduled runs.** `scripts/newsroom.sh` is ready for cron but has not been tested in a cron environment.
- **Cross-team retro.** The retro team can diagnose any single team's run, but cannot compare runs across days or teams to identify longitudinal trends.
- **PDF parsing.** Agents cannot parse PDF documents. They note PDF URLs and skip them.
