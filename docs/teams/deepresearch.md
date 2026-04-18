# Deep Research Team

Comprehensive web research with source collection, synthesis, and editorial review. Operates in workspace mode -- each run gets its own dated directory with structured output.

## Orchestrator

The orchestrator has restricted tools (`read,find,ls,grep` via `team-prompt.md` frontmatter) and cannot fetch URLs or run commands directly. It must delegate all work through the subagent pipeline. The body of `team-prompt.md` gives it detailed context about the team's agents, workflows, and constraints.

## Agents

### scout

| Field | Value |
|-------|-------|
| Tools | bash, read, ls |
| Skills | tavily |

Searches the web via the Tavily API for high-quality sources on a research topic. Returns a numbered list of URLs with titles and relevance notes. Formulates multiple search queries to cover different angles.

### collector

| Field | Value |
|-------|-------|
| Tools | bash, write, read, ls |
| Skills | playwright |

Fetches a single URL via headless browser (`playwright-cli`), strips boilerplate and ads, and saves cleaned content to `sources/<slug>.md` with YAML frontmatter. Takes a screenshot to `screenshots/<slug>.png`. Deployed in parallel -- one instance per URL from the scout's list. Each instance gets a unique collector number to avoid browser session collisions.

### writer

| Field | Value |
|-------|-------|
| Tools | read, find, ls, write |
| Skills | none (`no-skills: true`) |

Reads all files in `sources/` and synthesizes them into a structured research report with inline source references. Saves the draft to `drafts/report.md`. Follows a strict template: title, executive summary, subsections with citations, and a sources list with screenshot references.

### editor

| Field | Value |
|-------|-------|
| Tools | read, find, ls, write |
| Skills | none (`no-skills: true`) |

Reviews the draft against source files for accuracy, completeness, and structure. Verifies citations, checks screenshot references, and produces the final report at `report.md` in the workspace root.

## Workflow

The standard pipeline runs four steps:

1. **scout** (single) -- searches for sources on the topic
2. **collector** (parallel) -- fetches and cleans each source URL, saves to `sources/` and `screenshots/`
3. **writer** (single) -- synthesizes all sources into `drafts/report.md`
4. **editor** (single) -- reviews and produces final `report.md`

## Workspace Structure

Each run creates a dated directory under `workspaces/deepresearch/`:

```
workspaces/deepresearch/2026-04-12-141259/
├── sources/          # Cleaned source files (markdown + YAML frontmatter)
├── screenshots/      # Page screenshots (PNG)
├── drafts/           # Intermediate report draft
├── sessions/         # Session logs (orchestrator + all subagents)
└── report.md         # Final deliverable
```

## Configuration

All orchestrator configuration is in `team-prompt.md` YAML frontmatter:

```yaml
---
name: Deep Research
description: Search, collect, synthesize, report. Each run gets its own workspace.
tools: read, find, ls, grep
---
```

The body of `team-prompt.md` provides the orchestrator's system prompt with team context and workflow instructions.

| File | Purpose |
|------|---------|
| `workspace.conf` | Lists subdirectories to pre-create (`sources`, `screenshots`, `drafts`, `sessions`) |
| `team-prompt.md` | Orchestrator config (frontmatter) and system prompt (body) |

## Usage

```bash
# Start a new research run
p deepresearch "What are the latest developments in WebTransport protocol?"

# List past workspaces
p deepresearch --list

# Resume the most recent workspace
p deepresearch --resume

# Resume a specific workspace by prefix
p deepresearch --resume 2026-04-12
```

## Running Evals

```bash
# Quick smoke test (4 prompts)
./evals/run-eval.sh deepresearch evals/deepresearch-short.txt

# Comprehensive suite (20+ prompts)
./evals/run-eval.sh deepresearch evals/deepresearch-long.txt

# Results saved to evals/results/deepresearch/<eval-name>/<timestamp>/
```
