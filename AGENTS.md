# AGENTS.md

dot-pi is a self-improving agentic system built on the [pi coding agent](https://github.com/nichochar/pi-mono). Agent teams run on cheap/free models, a retro team diagnoses failures, and a frontier model (you) implements fixes based on the diagnosis.

## The Loop

1. Agent team runs and produces output + session logs
2. Retro team parses sessions, writes a lean diagnosis (`workspaces/retro/*/retro.md`)
3. You read the diagnosis and implement systemic fixes
4. The improved system runs again

## Read These First

- `docs/architecture.md` — system design, orchestration, session format, constraints
- `docs/newsroom.md` — six-phase editorial workflow
- `docs/retro.md` — session analysis, pathology catalog
- `docs/formats.md` — canonical output templates

## Key Facts

- Agent definitions are `agents/*.md` (YAML frontmatter + system prompt body). Teams are composed in `agents/teams.yaml`.
- The orchestrator's `.md` body is **replaced** at runtime by `extensions/orchestration/agent-team-2.ts`. Workflow instructions come from `prompts/` (interactive) or `scripts/` (headless). These must be kept in sync manually.
- Three-tier dispatch: orchestrator (dispatch only) -> leads (`role: lead`, tools + dispatch) -> workers (tools only).
- Sub-agent output returned to the dispatcher is truncated to 8KB. Agents write full output to disk.
- Sub-agent session files (`workspaces/*/sessions/*.json`) are JSONL despite the `.json` extension.
- `reference/` is gitignored and read-only (external repos). `workspaces/` and `sessions/` are also gitignored.
- Update `docs/` after structural changes — the docs are part of the improvement loop.
