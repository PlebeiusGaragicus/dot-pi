# Retro Agent Team

The retro team diagnoses agent team runs by parsing session JSONL files and reviewing workspace output. Its core value proposition: **digest hundreds of kilobytes of session logs on free/cheap pi agents so you don't burn expensive frontier model tokens reading raw transcripts.**

The retro team is generic — it works on any agent team's output, not just the newsroom.

## Agents

| Agent | Role | Tools | Dispatched by |
|-------|------|-------|---------------|
| `retro-editor` | Orchestrator / synthesizer | `dispatch_agent` only (top-level) | User |
| `retro-session-analyst` | JSONL parser, trajectory tracer | `read,bash,write` | Editor |
| `retro-output-reviewer` | Workspace output assessor | `read,bash,write` | Editor |

## Two-Workspace Model

The retro team operates across two workspaces:

- **Target workspace** — the workspace being analyzed (e.g., `workspaces/newsroom/2026-04-08_1446/`). Analysts READ session files and output files from here.
- **Retro workspace** — the retro team's own timestamped directory (e.g., `workspaces/retro/2026-04-08_1520/`). All analysis output is WRITTEN here.

This separation keeps the target workspace clean — no retro artifacts pollute the original run's output.

```
workspaces/retro/2026-04-08_1520/
  session.jsonl          # retro editor's own session
  sessions/              # retro sub-agent sessions
  retro.md               # final synthesized diagnosis
  session-analysis.md    # from retro-session-analyst
  output-review.md       # from retro-output-reviewer
```

The target workspace path is passed to the dispatcher via the `RETRO_TARGET` environment variable, which `agent-team-2.ts` injects into the system prompt as a `## Retro Target` block. The retro workspace path comes from `AGENT_WORKSPACE`, injected as the `## Workspace` block.

## How It Works

### Phase 1: Analysis (parallel)

The editor dispatches both analysts simultaneously:

**Session analyst** reads every session file (main JSONL + sub-agent sessions), runs a battery of Python parsing scripts embedded in its prompt, and produces a structured trajectory report. This is the heavy-lifting agent — session files can be 30-344KB each with individual lines up to 200KB (because `dispatch_agent` tool results embed entire sub-agent transcripts).

**Output reviewer** reads all markdown files in the target workspace and assesses whether the team produced what it was supposed to: are expected files present, is content substantive, is structure consistent?

Both analysts write their reports to the **retro workspace**, not the target workspace.

### Phase 2: Diagnosis

The editor combines:
1. The user's own observations (passed via `$@` in the `/retro` command)
2. The session analyst's pathology findings
3. The output reviewer's completeness assessment

And writes `retro.md` to the retro workspace — a lean, severity-ranked diagnosis designed to be pasteable into a frontier model session.

## Running

### Interactive — by team name

```bash
pretro newsroom
# retro editor already knows the target — just type:
/retro The editor seemed to dispatch itself. Geo desk only covered Iran.
```

The team name (`newsroom`) is resolved to the latest timestamped run under `workspaces/newsroom/`.

### Interactive — by full path

```bash
pretro ~/dot-pi/workspaces/newsroom/2026-04-08_1446
/retro Agent looped on search queries
```

### Interactive — auto-discover latest

```bash
pretro
/retro
```

With no argument, `pretro` finds the most recent workspace across all teams (excluding retro's own workspaces).

### Headless — by team name

```bash
bash ~/dot-pi/scripts/retro.sh newsroom
```

### Headless — by full path

```bash
bash ~/dot-pi/scripts/retro.sh ~/dot-pi/workspaces/newsroom/2026-04-08_1446
```

### Headless — auto-discover

```bash
bash ~/dot-pi/scripts/retro.sh
```

### Chaining newsroom + retro

```bash
bash ~/dot-pi/scripts/newsroom.sh && bash ~/dot-pi/scripts/retro.sh newsroom
```

### Target resolution logic

Both `pretro` and `scripts/retro.sh` share the same resolution logic:

1. If the argument is a directory that exists, use it as-is (full path)
2. If a directory exists at `~/dot-pi/workspaces/$ARG/`, treat it as a team name and pick the latest timestamped subdirectory
3. If no argument, find the latest workspace across all teams (excluding `workspaces/retro/`)

## Session File Format

Pi session files are JSONL (one JSON object per line). Each line has a `type` field:

```jsonl
{"type":"session", "id":"...", "timestamp":"...", "cwd":"..."}
{"type":"model_change", "provider":"...", "modelId":"..."}
{"type":"message", "message":{"role":"user", "content":[...]}}
{"type":"message", "message":{"role":"assistant", "content":[...], "usage":{...}}}
{"type":"message", "message":{"role":"toolResult", "toolName":"...", "isError":false, ...}}
```

### Where session files live for team runs

For workspace-based teams (like newsroom), all session files are co-located in the workspace:

```
workspaces/newsroom/2026-04-08_1430/
  session.jsonl              # Main dispatcher session
  sessions/
    desk-geopolitics.json    # Sub-agent sessions (JSONL despite .json extension)
    desk-scitech.json
    newsroom-researcher.json
    newsroom-fact-checker.json
    newsroom-copy-editor.json
```

The session analyst should **not** need to look in `~/dot-pi/sessions/` for team runs. That directory is only used by non-team aliases (`pchat`, `pweb`, `pexplain`).

### Main session (`session.jsonl`)

The top-level dispatcher's full conversation. Key detail: `dispatch_agent` tool results embed the **entire sub-agent transcript** as a JSON string inside the `content` field. This makes individual lines enormous — up to 200KB. The parsing toolkit handles this by extracting specific fields rather than reading entire lines into context.

### Sub-agent sessions (`sessions/*.json`)

Despite the `.json` extension, these are JSONL. Each contains one sub-agent's complete tool call history. These files are typically 20-90KB and contain the actual tool calls (SearXNG queries, file writes, curl fetches) that the sub-agent executed.

When an agent is dispatched multiple times in a single run (e.g., scan mode then investigate mode), subsequent dispatches append to the same session file via the `-c` (continue) flag. The session file therefore contains the agent's entire history across all dispatches within that run.

### `usage` field in assistant messages

Assistant messages include a `usage` object:

```json
{
  "input": 12345,
  "output": 678,
  "cacheRead": 9000
}
```

- `input` — tokens consumed from the prompt
- `output` — tokens generated by the model
- `cacheRead` — tokens served from cache (reduces cost)

## The JSONL Parsing Toolkit

The session analyst's prompt embeds six `bash` + `python3 -c` recipes. These are the primary tools for diagnosing runs. They were developed from analyzing real runs and are designed to extract specific signals from large files without reading entire files into the agent's context.

### 1. Survey all session files

```bash
find WORKSPACE_PATH -name '*.jsonl' -o -name '*.json' | while read f; do
  lines=$(wc -l < "$f"); chars=$(wc -c < "$f")
  echo "$f: $lines lines, $chars chars"
done
```

Finds the main session (`session.jsonl`) and all sub-agent sessions (`sessions/*.json`). Reports line count and byte size — useful for identifying unusually large sessions.

### 2. Event timeline

```bash
python3 -c "
import json
with open('SESSION_FILE') as f:
    for i, line in enumerate(f):
        d = json.loads(line.strip())
        t = d.get('type','?')
        extra = ''
        if t == 'message':
            msg = d['message']
            role = msg.get('role','?')
            if role == 'assistant':
                content = msg.get('content',[])
                tools = [c.get('name','') for c in content if isinstance(c,dict) and c.get('type')=='toolCall'] if isinstance(content,list) else []
                usage = msg.get('usage',{})
                extra = f' tools={tools} in={usage.get(\"input\",0)} out={usage.get(\"output\",0)}'
            elif role == 'toolResult':
                err = msg.get('isError',False)
                extra = f' tool={msg.get(\"toolName\",\"?\")} error={err}'
            print(f'{i:3d} | {len(line):>8,} chars | {role:12s}{extra}')
        else:
            print(f'{i:3d} | {len(line):>8,} chars | {t}')
"
```

Produces a line-by-line event log with type, role, tool names, and character count per line. The character count is the key signal for context bloat — lines > 50K chars indicate dispatch results embedding full transcripts.

### 3. Error finder

Extracts all `isError: true` tool results with the first 300 characters of the error text. The most common errors:
- "Tool bash not found" — agent tried a tool it doesn't have
- "Agent X not found" — typo in agent name or wrong team
- `curl` failures — SearXNG down or bad URL

### 4. Loop detector

Finds 3+ consecutive identical tool calls (same tool name and arguments). The main signal for a stuck agent. Common loop patterns:
- Desk agent re-running the same SearXNG query with identical parameters
- Agent retrying a failed tool call without changing anything
- Editor dispatching the same agent with the same task

### 5. Dispatch chain extractor

For the main session only. Extracts the sequence of `dispatch_agent` calls with agent names and task previews (first 200 chars). This is the fastest way to understand the editor's orchestration decisions: which agents were dispatched in what order, and what they were asked to do.

### 6. Token usage summary

Aggregates input/output/cache token counts across all assistant messages in a session. Useful for understanding cost and for detecting context accumulation (steadily increasing input tokens across turns suggests the session is growing).

## What It Diagnoses

| Pathology | Description | How detected |
|-----------|-------------|--------------|
| Tool-not-found | Agent tried a tool it doesn't have | Error finder: "Tool X not found" |
| Self-dispatch | Agent dispatching itself as a workaround | Dispatch chain: agent dispatching its own name |
| Loops | Same tool call repeated 3+ times | Loop detector (200-char arg comparison, requires verification) |
| Context bloat | Tool result > 50KB ingested into context | Event timeline: line char count |
| Prompt non-compliance | Agent ignoring specific instructions | Manual inspection of tool call arguments |
| Wasted work | Queries returning zero results | Event timeline: small tool results after search calls |
| Agent confusion | Wrong agent dispatched, garbled task | Dispatch chain: task content mismatch with agent role |
| Missing output | Expected file not written | Output reviewer: empty or absent files |
| Incomplete run | Run terminated before all phases completed | Phase completion detector (recipe 8) |
| Dispatch gaps | Story slug dispatched but no output file | Dispatch-to-output coverage (recipe 7) |
| Frontmatter mismatch | Count fields don't match actual content | Output reviewer: frontmatter validation |
| Broken references | Referenced source paths don't exist on disk | Output reviewer: cross-reference check |

### Cancellation Handling

User cancellation (stopping a run mid-execution) is **normal during testing**. The retro team handles this gracefully:

- Incomplete runs are flagged as **INFO** ("Run terminated after Phase N of M"), not as critical issues.
- Files that would have been produced by un-executed phases are **not** flagged as "missing."
- Clean exits with no crash trace are assumed to be intentional cancellation.

This prevents noisy false positives when the user is iterating on prompt design and stops runs early.

### Real examples from early runs

- **Editor trying `bash`:** The editor (top-level dispatcher) tried to run `bash` to discover the workspace path. The extension restricts the dispatcher to `dispatch_agent` only. Error: "Tool bash not found". The editor then dispatched itself as a sub-agent to get `bash` access — a creative but pathological workaround.
- **Context overflow:** A desk agent pulled full content from SearXNG results (not just titles/URLs) during scan mode, inflating its context to 80K+ tokens and degrading response quality in subsequent turns.
- **`time_range=day`:** Desk agents used `time_range=day` despite the prompt specifying 96-hour coverage. This is a common instruction-following failure on smaller models.

## Design Rationale

### Why diagnosis only, no prescriptions?

The retro report is designed to be pasted into a frontier model session where the user says "implement these fixes." Prescribing solutions would require the retro agents to understand the full system architecture (extension behavior, prompt template mechanics, alias configuration), which is expensive context to load into cheap models. Instead, they provide a lean diagnosis and let the frontier model — which has the codebase and these docs in context — figure out the fix.

### Why a separate output reviewer?

The session analyst focuses on **process** (what agents did). The output reviewer focuses on **product** (what was produced). These are complementary views:
- A run can have clean process but bad output (agent worked fine but search results were poor)
- A run can have good output despite bad process (agent looped but eventually recovered)

Separating them also allows parallel dispatch — both analysts can run simultaneously.

### Why separate retro workspaces?

Earlier iterations wrote retro analysis files into the target workspace. This polluted the original run's output with files like `retro.md` and `retro-session-analysis.md`, making it harder to assess what the original team actually produced. The two-workspace model keeps the original run pristine and makes retro runs independently addressable and archivable.

### Why Python one-liners instead of just grep?

Session JSONL lines can be up to 200KB of nested JSON. `grep` finds text matches but can't parse structure — you can't distinguish a tool call error from an error string appearing in a news article about errors. The `python3 -c` recipes parse the JSON structure and extract specific fields.

For quick spot-checks, `rg` works:

```bash
# How many errors in a session?
rg '"isError":true' session.jsonl | wc -l

# Find all dispatch_agent calls
rg 'dispatch_agent' session.jsonl
```

But for structured analysis (dispatch chains, loop detection, token aggregation), the Python recipes are necessary.

### Why `.json` extension for JSONL files?

This is a quirk of `agent-team-2.ts`, which names sub-agent session files as `<agent-name>.json`. The files are actually JSONL (one JSON object per line). This matters because `json.load()` will fail on these files — they must be read line-by-line with `json.loads()` per line. The parsing toolkit handles this correctly. A future fix would be to rename them to `.jsonl`, but this requires updating the extension.

## The Meta-Improvement Loop

The retro team is one tier of a three-part self-improvement cycle:

```
1. Agent Team Run → produces output + session logs
        |
        v
2. Retro Analysis → produces lean diagnosis (retro.md)
        |
        v
3. Developer + Frontier Model → reads diagnosis, implements systemic fixes
        |
        v
1. Agent Team Run (improved) → ...
```

The retro team handles step 2. It does NOT prescribe solutions — that is step 3's job. The retro report is designed to be compact enough to paste into a frontier model session alongside these docs for full-context implementation.

The system's docs (`docs/`) are part of the loop. When the frontier model makes changes based on a retro report, the docs should be updated to reflect the new system state. This ensures the next retro run's analysts and the next frontier session both have accurate context.
