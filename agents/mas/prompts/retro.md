# Retro — MAS session retrospective

Review a completed or partial **`mas`** run from durable traces: orchestrator JSONL under the overlay plus worker JSONL under **`subagent-traces/`**. Focus on failures, bad trajectories, weak instruction following, tool errors, and multi-agent handoff issues (especially with smaller open-source models).

## Goal

Produce a concise, evidence-backed analysis of one named **`mas`** session. Prefer grounded references (paths, line excerpts, **`manifest.json`** fields) over speculation. The primary user input is the **session display name** set via **`/name`** in `mas`, which is stored in orchestrator JSONL as a **`session_info`** record with **`name`** (and **`id`**). That name may hint at what went wrong or what to emphasize.

**Correlation rule:** worker bundles under **`subagent-traces/<run-id>/`** include **`orchestrator-session.jsonl`**, a symlink to the parent orchestrator **`*.jsonl`**. **`/retro`** uses that symlink as the **only** join key between a named session and a trace bundle. There is no legacy fallback (no grepping orchestrator logs for **`traceRunId`** for old bundles without the symlink).

## Required Trajectory

Follow these phases in order. Do not skip user checkpoints when this workflow says to use **`questionnaire`**.

### 1. Preflight

- Parse the user request at the end of this prompt for:
  - the **session name** string to match against **`session_info.name`**, or an explicit **`session_info.id`** if the user pasted one
  - optional focus (e.g. “tool failures only”, “orchestrator reasoning”, “worker X”)
- If the session name or id is missing or unusably vague, use **`questionnaire`** once to obtain it before delegating workers.
- After workers have been invoked, do not use **`questionnaire`** except where this workflow explicitly requires a user decision.

### 2. Cwd-key for this project

Compute the **`mas` sessions subdirectory** for the **current working directory** the same way **`dispatch-agent`** does:

- Take **`ctx.cwd`** (the directory where **`mas`** is running).
- Strip leading slashes from the path, replace every remaining **`/`** with **`-`**, then wrap as **`--<encoded>--`**. Example: **`/Users/me/proj/foo`** becomes **`--Users-me-proj-foo--`**.

You will pass this exact directory name into the **`scout`** task so search stays under **`$DOT_PI_OVERLAY/mas/sessions/<cwd-key>/`** only (not all projects).

### 3. Locate session and trace bundle (`scout`) — single delegation

Call **`scout`** exactly **once**. Scope:

- **`$DOT_PI_OVERLAY/mas/sessions/<cwd-key>/`** (resolve **`$DOT_PI_OVERLAY`** from the environment; use the **cwd-key** from §2).
- **`$DOT_PI_OVERLAY/mas/subagent-traces/`**

`scout` may only use **`ls`**, **`find`**, **`grep`**, and **`read`** — no shell pipelines, no **`jq`**.

The scout task must:

1. **Orchestrator file:** Under **`.../mas/sessions/<cwd-key>/`**, use **`grep`** with a pattern that requires **`"type":"session_info"`** (allow minor spacing variants) **and** either the user's **`name`** or **`id`**, so prose lines that merely mention the name are not mistaken for **`session_info`**. Return the **absolute path** to the matching **`*.jsonl`** and the matching line excerpt.
2. **Trace bundle:** Under **`.../mas/subagent-traces/`**, enumerate run-id subdirectories. For each candidate, check for **`orchestrator-session.jsonl`**. Determine which bundle’s symlink resolves to the **same real path** as the orchestrator **`*.jsonl`** from step 1 (e.g. compare canonical paths: `read`/`grep` as needed; if **`read`** follows the symlink, compare content identity with a small read of the orchestrator file head, or use whatever read-only comparison **`scout`** can apply consistently).
3. Return **`traceRunId`** (directory basename), path to **`manifest.json`**, list of worker **`*.jsonl`** files in that bundle, and confirmation the symlink matches the orchestrator file from step 1.

If **no** bundle has **`orchestrator-session.jsonl`** pointing at that orchestrator file, stop with a concise blocker: the user needs a **`mas`** build that creates **`orchestrator-session.jsonl`** in each trace bundle (no heuristic correlation).

If **`scout`** finds no **`session_info`** match under the cwd-key subtree, use **`questionnaire`** to widen the name, try a different id, or cancel.

If multiple **`session_info`** rows still tie-break badly, use **`questionnaire`**.

### 4. Analysis (`coder`)

Call **`coder`** once for **read-only** work (no edits to the user’s project repo, no new files unless the user explicitly asked for a saved report path).

The **`coder`** task must:

- Use the orchestrator **`*.jsonl`** path and the **`subagent-traces/<run-id>/`** tree from §3. Prefer reading the orchestrator log via **`orchestrator-session.jsonl`** inside the bundle when convenient (same content as the canonical path).
- Use **`jq`**, **`grep`**, **`head`**, **`tail`**, **`wc`** as needed. Do **not** run destructive commands.
- Summarize: non-zero **`exitCode`** on **`manifest.json`** workers, **`stderr`**, **`errorMessage`**, **`stopReason`**, failed tool / **`isError`** patterns in worker JSONL, and orchestration issues (wrong worker choice, skipped validation, vague handoffs).
- Add **prioritized recommendations** and brief instruction-following / model-quality notes (bounded excerpts only — not full file dumps).

This **`coder`** pass replaces a separate **`ask`/judge** step: the analysis and critique are delivered here.

### 5. Final Response (orchestrator)

Reply briefly in chat:

- Orchestrator **`*.jsonl`** path and **`subagent-traces/<run-id>/`** reviewed.
- Top findings with severity.
- Optional next step (e.g. adjust a workflow prompt, change model).

Do not paste entire JSONL files unless the user explicitly asked.

## Artifact Conventions

- **Orchestrator sessions:** **`$DOT_PI_OVERLAY/mas/sessions/<cwd-key>/*.jsonl`**
- **Worker traces:** **`$DOT_PI_OVERLAY/mas/subagent-traces/<run-id>/manifest.json`**, worker **`*.jsonl`**, and **`orchestrator-session.jsonl`** (symlink to the orchestrator JSONL for that **`mas`** process’s cwd-key sessions dir).
- Optional saved report: only if the user asked for a file path; otherwise **`writer`** is not required.

## Stop Conditions

- Missing session name/id after **`questionnaire`**.
- No **`session_info`** match under the cwd-key **`sessions/`** subtree.
- No trace bundle with **`orchestrator-session.jsonl`** resolving to that orchestrator file (stop with blocker; no legacy fallback).
- **`coder`** unavailable or blocked — report blocker; do not invent analysis.

## Final Response

Keep the final response short. Prefer a one-paragraph summary plus bullets for the worst issues with evidence pointers (path + hint).

## User Request

Treat the text below as the retrospective request: session **`/name`** (or **`session_info.id`**), optional focus, and any scope limits.

**User prompt:**
`$@`
