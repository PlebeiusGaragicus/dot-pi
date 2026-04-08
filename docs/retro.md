# Retro Agent Team

The retro team diagnoses agent team runs by parsing session JSONL files and reviewing workspace output. Its core value proposition: **digest hundreds of kilobytes of session logs on free/cheap pi agents so you don't burn expensive frontier model tokens reading raw transcripts.**

The retro team is generic -- it works on any agent team's output, not just the newsroom.

## Agents

| Agent | Role | Tools | Dispatched by |
|-------|------|-------|---------------|
| `retro-editor` | Orchestrator / synthesizer | `dispatch_agent` only | User (top-level) |
| `retro-session-analyst` | JSONL parser, trajectory tracer | `read,bash,write` | Editor |
| `retro-output-reviewer` | Workspace output assessor | `read,bash,write` | Editor |

## How It Works

### Phase 1: Analysis (parallel)

The editor dispatches both analysts simultaneously:

**Session analyst** reads every session file (main JSONL + sub-agent sessions), runs a battery of parsing scripts, and produces a structured trajectory report. This is the heavy-lifting agent -- session files can be 30-344KB each with individual lines up to 200KB.

**Output reviewer** reads all markdown files in the workspace and assesses whether the team produced what it was supposed to: are expected files present, is content substantive, is structure consistent?

### Phase 2: Diagnosis

The editor combines:
1. The user's own observations (passed via `$@` in the prompt)
2. The session analyst's pathology findings
3. The output reviewer's completeness assessment

And writes `retro.md` -- a lean, severity-ranked diagnosis.

## Running

```bash
pretro
# Then in the pi session:
/retro The editor seemed to dispatch itself. Geo desk only covered Iran.
```

Or with an explicit workspace:

```bash
pretro
/retro --workspace ~/dot-pi/workspaces/newsroom/2026-04-08 Agent looped on search queries
```

The `$@` text after `/retro` becomes the user's observations, which the editor passes to both analysts and incorporates into the final diagnosis.

## Session File Format

Pi session files are JSONL (one JSON object per line). There are two locations:

### Main session (`~/dot-pi/sessions/*.jsonl`)

The top-level dispatcher's full conversation. Each line is one of:

```jsonl
{"type":"session", "id":"...", "timestamp":"...", "cwd":"..."}
{"type":"model_change", "provider":"...", "modelId":"..."}
{"type":"message", "message":{"role":"user", "content":[...]}}
{"type":"message", "message":{"role":"assistant", "content":[...], "usage":{...}}}
{"type":"message", "message":{"role":"toolResult", "toolName":"...", "isError":false, ...}}
```

Key detail: `dispatch_agent` tool results embed the **entire sub-agent transcript** as a JSON string inside the `content` field. This makes individual lines enormous (up to 200KB). The session analyst knows how to handle this.

### Sub-agent sessions (`workspaces/.../sessions/*.json`)

Despite the `.json` extension, these are also JSONL. Each contains one sub-agent's complete tool call history in the same format as above. These are the files you'd read to understand what a specific desk agent or researcher actually did.

## The JSONL Parsing Toolkit

The session analyst's prompt includes six battle-tested recipes for parsing session files. These were developed from analyzing actual runs:

1. **Survey** -- find all session files with line counts and byte sizes
2. **Event timeline** -- type, role, tool name, and line size for every event
3. **Error finder** -- extract all `isError: true` tool results with error text
4. **Loop detector** -- find 3+ consecutive identical tool calls (the main signal for a stuck agent)
5. **Dispatch chain** -- extract the sequence of `dispatch_agent` calls with agent names and task previews
6. **Token usage** -- aggregate input/output/cache token counts per session

These recipes use `python3 -c` one-liners that the agent runs via `bash`. They're designed to extract specific signals from large files without reading the entire file into the agent's context.

## What It Diagnoses

The retro team looks for these pathologies:

| Pathology | What it means | Example from real run |
|-----------|--------------|----------------------|
| Tool-not-found | Agent tried a tool it doesn't have | Editor tried `bash` (dispatchers only get `dispatch_agent`) |
| Self-dispatch | Agent dispatching itself as a workaround | Editor dispatched `newsroom-editor` to run shell commands |
| Loops | Same tool call repeated 3+ times | Desk agent re-running identical search query |
| Context bloat | Tool result > 50KB ingested into context | Dispatch result embedding full sub-agent transcript |
| Prompt non-compliance | Agent ignoring specific instructions | Using `time_range=day` when prompt says 96 hours |
| Wasted work | Queries returning zero results | Search for very specific terms that don't match |
| Agent confusion | Wrong agent dispatched, garbled task | Editor dispatching desk agent with copy-editor's task |
| Missing output | Expected file not written | Story file referenced but never created |

## Design Rationale

### Why diagnosis only, no prescriptions?

The retro report is designed to be pasted into a frontier model session where the user can say "implement these fixes." Prescribing solutions would require the retro agents to understand the full system architecture, which is expensive context. Instead, they provide a lean diagnosis and let the frontier model -- which has the full codebase in context -- figure out the fix.

### Why a separate output reviewer?

The session analyst focuses on process (what agents did). The output reviewer focuses on product (what was produced). These are complementary views. A run can have clean process but bad output (agent worked fine but the search results were poor) or good output despite bad process (agent looped but eventually recovered).

### Why not just use grep?

Session JSONL lines can be up to 200KB of nested JSON. `grep` finds text matches but can't parse the structure -- you can't distinguish a tool call error from an error mentioned in a news article about errors. The `python3 -c` recipes parse the JSON structure and extract specific fields.

That said, for quick spot-checks, `rg` with `jq` works:

```bash
# Quick check: how many errors in a session?
rg '"isError":true' session-file.jsonl | wc -l

# Find all dispatch_agent calls
rg 'dispatch_agent' session-file.jsonl | python3 -c "
import sys, json
for line in sys.stdin:
    d = json.loads(line.strip())
    # ...parse as needed
"
```
