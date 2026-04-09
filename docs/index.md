# dot-pi

> Dotfiles for your pi coding agent — a self-improving agentic system

---

Dotfiles for the [pi coding agent](https://github.com/nichochar/pi-mono). Clone, source the aliases, and you have a full agent toolkit: single-agent commands, multi-agent teams, web research, prompt templates, skills, themes, and self-diagnostic tooling.

The system is designed around a **self-improvement loop**: agent teams produce output, the retro team diagnoses what went wrong, and a human takes the diagnosis to a frontier model to implement fixes. See [Architecture](architecture.md) for how this works.

## Quick Start

```bash
git clone https://github.com/PlebeiusGaragicus/dot-pi ~/dot-pi
cp ~/dot-pi/example.env ~/dot-pi/.env   # add your API key
echo '[ -f ~/dot-pi/pi-aliases ] && source ~/dot-pi/pi-aliases' >> ~/.zshrc
source ~/.zshrc
```

## Commands

| Command    | What it does                                           |
|------------|--------------------------------------------------------|
| `pchat`    | Conversational chatbot (read-only tools)               |
| `pexplain` | Codebase analyst — explores and reports on a project   |
| `pweb`     | Web research assistant via local SearXNG               |
| `pnews`    | Newsroom agent team — produces a news briefing         |
| `pretro`   | Retro team — diagnoses agent runs from session logs    |
| `pteam`    | Generic agent team orchestrator (grid dashboard)       |
| `pteam2`   | Generic agent team orchestrator (inline output)        |

All commands accept `"$@"` pass-through, so you can append any pi flags or an initial prompt.

## Directory Structure

```
agents/            Agent definitions (.md with frontmatter)
agents/teams.yaml  Team compositions — which agents work together
docs/              Documentation — architecture, team explainers, design rationale
extensions/        Pi extensions (TypeScript) — orchestration, UI
prompts/           Prompt templates — available as /commands in interactive sessions
scripts/           Shell scripts for headless/scheduled runs
sessions/          Session archives (.jsonl) — transcripts of non-team alias runs
skills/            Skill files — teach agents how to use specific tools
themes/            Color themes for the pi TUI
workspaces/        Agent team outputs — per-team, per-run, with co-located sessions
reference/         Reference repos (gitignored) — pi-mono source, pi-recipes examples
```

## Agent Teams

Teams are defined in `agents/teams.yaml`. Each team is a list of agent names that map to `.md` files in `agents/`.

```yaml
newsroom:
  - newsroom-editor
  - desk-reporter
  - newsroom-scraper
  - newsroom-researcher
  - newsroom-vlm
  - newsroom-fact-checker
  - newsroom-copy-editor

retro:
  - retro-editor
  - retro-session-analyst
  - retro-output-reviewer
```

The team orchestrator (`agent-team-2.ts`) gives the first agent a `dispatch_agent` tool to coordinate the team. Sub-agents run as separate pi processes with their own tools and context. The `AGENT_WORKSPACE` env var is injected into the dispatcher's system prompt so it knows where agents should write output.

Set `AGENT_TEAM=name` to auto-select a team on startup (used by `pnews`, `pretro`).

## Documentation

- [Architecture](architecture.md) — how orchestration works, session format, alias mechanics, limitations
- [Newsroom](newsroom.md) — five-phase editorial workflow for automated news briefings
- [Retro](retro.md) — session log analysis, JSONL parsing toolkit, pathology catalog

## Adding Your Own

**Agent:** Create `agents/your-agent.md` with frontmatter (`name`, `description`, `tools`) and a system prompt body.

**Team:** Add a new entry to `agents/teams.yaml` listing your agent names. The first agent becomes the dispatcher.

**Extension:** Add a `.ts` file to `extensions/` and load it with `-e` in your alias.

**Skill:** Create a directory under `skills/` with a `SKILL.md` and optional `install.md`.

**Prompt template:** Create a `.md` file in `prompts/` with a `description` in frontmatter. It becomes a `/command` in interactive sessions.

**Theme:** Add a `.json` file to `themes/`.

## Reference Repos

These live in `reference/` (gitignored) and provide source code and examples:

- **pi-mono** — pi coding agent source. Useful for understanding the extension API, tool system, and session format.
- **pi-recipes** — example extensions, agents, teams, prompts, and workflows.
- **feynman** — advanced prompt templates and research workflows.
