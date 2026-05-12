# Retro — MAS session retrospective

Review a completed or partial **`mas`** run from durable traces: orchestrator JSONL under the overlay plus worker JSONL under **`subagent-traces/`**. Focus on failures, bad trajectories, weak instruction following, tool errors, and multi-agent handoff issues (especially with smaller open-source models).

## Goal

Produce a concise, evidence-backed critique of one named **`mas`** session. Prefer grounded references (paths, line excerpts, manifest fields) over speculation. The primary user input is the **session display name** set via **`/name`** in `mas`, which is stored in orchestrator JSONL as a `session_info` record with a `name` field (and `id`). That name may also hint at what went wrong or what to emphasize in the review.

## Required Trajectory

Follow these phases in order. Do not skip user checkpoints when this workflow says to use `questionnaire`.

### 1. Preflight

- Parse the user request at the end of this prompt for:
  - the **session name** string to match against `session_info.name` (from `/name`), or an explicit **`session_info.id`** if the user pasted one
  - optional focus (e.g. “tool failures only”, “orchestrator reasoning”, “worker X”)
- If the session name or id is missing or unusably vague, use **`questionnaire`** once to obtain it before delegating workers.
- After workers have been invoked, do not use **`questionnaire`** except where this workflow explicitly requires a user decision.

### 2. Locate orchestrator session (`scout`)

Call **`scout`** once. Scope must include **`$DOT_PI_OVERLAY/mas/sessions/`** (resolve from the environment). `scout` may only use **`ls`**, **`find`**, **`grep`**, and **`read`** — no shell pipelines, no **`jq`**.

The scout task must:

- Under **`$DOT_PI_OVERLAY/mas/sessions/`**, search recursively for `*.jsonl` files.
- Use **`grep`** to find lines containing **`"type":"session_info"`** (or equivalent spacing) whose **`name`** field matches the user’s session name, or whose **`id`** matches if the user supplied an id.
- Return **absolute paths** to every candidate JSONL file, the **matching line(s)** or short excerpts, and note if multiple files match.
- If no match: report “not found” with directories searched; do not invent matches.

If **`scout`** reports no match, use **`questionnaire`** to widen the name, try a different id, or cancel.

If multiple candidates remain ambiguous, use **`questionnaire`** to pick one.

### 3. Correlate worker trace bundle (`scout`)

Still read-only: use **`scout`** (or continue the same `scout` reply if it already listed this) to locate **`$DOT_PI_OVERLAY/mas/subagent-traces/`**.

Correlation order (try each until one succeeds):

1. **`grep`** the selected orchestrator **`*.jsonl`** for **`traceRunId`**, **`traceDir`**, or **`subagent-traces`** substrings from logged `subagent` tool results — these tie the conversation to a bundle directory.
2. **`read`** **`manifest.json`** under candidate **`$DOT_PI_OVERLAY/mas/subagent-traces/<run-id>/`** directories. Prefer a manifest whose **`cwd`** matches the orchestrator session’s project and, when present, whose **`parentSessionInfoId`** or **`parentSessionInfoName`** matches the **`session_info`** you found in step 2.
3. If still ambiguous, use **`manifest.createdAt`** and worker **`startedAt`** values against timestamps near **`subagent`** tool lines in the orchestrator JSONL as a **heuristic**; if multiple bundles remain plausible, use **`questionnaire`**.

Return the chosen **`traceRunId`**, path to **`manifest.json`**, and listing of worker **`*.jsonl`** files in that bundle.

### 4. Structured trace mining (`coder`)

Call **`coder`** once for **read-only analysis** (no repository edits, no new files unless the user explicitly asked for a saved report).

The coder task must:

- Operate only on the orchestrator JSONL path and the **`subagent-traces/<run-id>/`** tree identified above.
- Use **`jq`**, **`grep`**, and small **`wc`/`head`/`tail`** slices as needed. Do **not** mutate tracked project files; do **not** run destructive commands.
- Summarize: non-zero **`exitCode`** on manifest workers, **`stderr`**, **`errorMessage`**, **`stopReason`**, failed tool patterns in JSONL (wording may vary by pi version — discover patterns from the files), and any obvious orchestrator mistakes (wrong worker, skipped validation, contradictory instructions).
- Keep output bounded: counts, short excerpts, and file references — not full session dumps.

If **`coder`** cannot run **`jq`** or hits permission errors, fall back to orchestrator-only review with **`scout`** excerpts and note the limitation.

### 5. Critique (`ask`)

Call **`ask`** once with persona **`judge`** (or an equivalent critical persona configured for **`ask`**).

Pass **inline excerpts only**: orchestrator snippets, **`coder`** findings, manifest worker summary, and at most a few short worker JSONL excerpts. **Never** ask **`ask`** to read paths or open files itself.

The critique task should cover:

- Failures and errors (tools, workers, exits).
- Orchestration issues (bad delegation, wrong capability, missing validation).
- Instruction-following and reasoning quality for weaker models.
- Concrete, prioritized recommendations.

### 6. Final Response (orchestrator)

Reply briefly in chat:

- Which orchestrator **`*.jsonl`** and **`subagent-traces/<run-id>/`** you reviewed.
- Top 3–7 findings with severity.
- Optional next step (e.g. re-run with a different model, tighten a workflow prompt).

Do not paste entire JSONL files unless the user explicitly asked.

## Artifact Conventions

- **Orchestrator sessions:** **`$DOT_PI_OVERLAY/mas/sessions/<cwd-key>/*.jsonl`** (overlay; survives **`pi update`**).
- **Worker traces:** **`$DOT_PI_OVERLAY/mas/subagent-traces/<run-id>/manifest.json`** plus worker **`*.jsonl`** in the same directory.
- **Manifest session linkage:** when the orchestrator extension could read them, **`manifest.json`** may include **`parentSessionInfoId`**, **`parentSessionInfoName`**, and **`parentOrchestratorSessionFile`** copied from the latest **`session_info`** in the orchestrator JSONL — use these to match bundles to named sessions.
- Optional saved report: only if the user asked for a file path; otherwise **`writer`** is not required.

## Stop Conditions

- Missing session name/id after **`questionnaire`**.
- No orchestrator JSONL match after search and user declines to adjust.
- No **`subagent-traces`** bundle can be correlated and the user declines heuristic picks.
- **`coder`** unavailable or blocked for read-only mining — continue with **`scout`** + **`ask`** only and state the gap.

## Final Response

Keep the final response short. Prefer a one-paragraph summary plus a bullet list of the worst issues and their evidence pointers (file + rough location).

## User Request

Treat the text below as the retrospective request: session **`/name`** (or **`session_info.id`**), optional focus, and any scope limits.

**User prompt:**
`$@`
