---
description: Diagnose an agent team run — parse sessions, review output, produce a lean retro report
---
Run a retrospective on an agent team run. $@

## Finding the Run

First, locate the workspace and session files to analyze.

If the user specified a workspace path above, use it. Otherwise, find the most recent run:

Dispatch **retro-session-analyst** with this preliminary task:
> Run `ls -lt ~/dot-pi/workspaces/*/` to find the most recent workspace directory. Then run `ls -lt ~/dot-pi/sessions/` to find session JSONL files. Return the workspace path and the most likely matching session JSONL filename (match by date).

## Phase 1 — Analysis

Once you have the workspace and session paths, dispatch both analysts:

**Dispatch retro-session-analyst:**
> Analyze the agent run at workspace [WORKSPACE]. The main session JSONL is at [SESSION_PATH]. Sub-agent sessions are in [WORKSPACE]/sessions/. Run your full toolkit: survey, timeline, errors, loops, dispatch chain, token usage. Write your analysis to [WORKSPACE]/retro-session-analysis.md. Pay special attention to: [USER'S OBSERVATIONS IF ANY].

**Dispatch retro-output-reviewer:**
> Review the output files in [WORKSPACE]. List all files, assess completeness and quality, check for missing or empty outputs. Write your review to [WORKSPACE]/retro-output-review.md.

## Phase 2 — Diagnosis

After both analysts return their summaries, synthesize a final retrospective:

1. Start with the user's observations (the text after `/retro`)
2. Combine with the session analyst's pathology findings
3. Add the output reviewer's completeness assessment
4. Write `retro.md` to the workspace with severity-ranked findings

The retro report should be lean enough to paste into a frontier model session for implementing fixes. Diagnosis only — do not prescribe solutions.
