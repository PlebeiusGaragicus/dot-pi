#!/bin/bash
set -euo pipefail

source "$HOME/dot-pi/.env"

# Resolve target workspace from first arg: team name, full path, or auto-discover
TARGET=""
if [ -n "${1:-}" ]; then
  if [ -d "$1" ]; then
    TARGET="$1"
  elif [ -d "$HOME/dot-pi/workspaces/$1" ]; then
    TARGET="$(ls -dt "$HOME/dot-pi/workspaces/$1"/*/ 2>/dev/null | head -1)"
  else
    echo "[retro] Unknown team or path: $1" && exit 1
  fi
fi
if [ -z "$TARGET" ]; then
  TARGET="$(ls -dt "$HOME/dot-pi/workspaces"/*/*/ 2>/dev/null | grep -v '/retro/' | head -1)"
fi
if [ -z "$TARGET" ]; then
  echo "[retro] No workspaces found to analyze." && exit 1
fi

RUN_ID=$(date +%Y-%m-%d_%H%M)
RETRO_WORKSPACE="$HOME/dot-pi/workspaces/retro/$RUN_ID"
mkdir -p "$RETRO_WORKSPACE/sessions"

export AGENT_TEAM="retro"
export AGENT_WORKSPACE="$RETRO_WORKSPACE"
export RETRO_TARGET="$TARGET"

echo "[retro] $(date '+%H:%M:%S') Target: $TARGET"
echo "[retro] Retro workspace: $RETRO_WORKSPACE"

pi -p \
  --session "$RETRO_WORKSPACE/session.jsonl" \
  -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
  --no-skills \
  --no-prompt-templates \
  "Run a retrospective on the agent team run at: $TARGET
Retro workspace (write all output here): $RETRO_WORKSPACE

Phase 1 — Analysis (dispatch both in parallel):
Dispatch retro-session-analyst: Analyze the agent run at workspace $TARGET. The main session is $TARGET/session.jsonl. Sub-agent sessions are in $TARGET/sessions/. Run your full toolkit: survey, timeline, errors, loops, dispatch chain, token usage. Write your analysis to $RETRO_WORKSPACE/session-analysis.md.
Dispatch retro-output-reviewer: Review the output files in $TARGET. List all files, assess completeness and quality, check for missing or empty outputs. Write your review to $RETRO_WORKSPACE/output-review.md.

Phase 2 — Diagnosis:
After both analysts return, synthesize a final retrospective. Combine the session analyst's pathology findings with the output reviewer's completeness assessment. Write retro.md to $RETRO_WORKSPACE with severity-ranked findings. Diagnosis only — do not prescribe solutions."

echo "[retro] $(date '+%H:%M:%S') Done. Report: $RETRO_WORKSPACE/retro.md"
