#!/bin/bash
set -euo pipefail

source "$HOME/dot-pi/.env"

DATE=$(date +%Y-%m-%d)
WORKSPACE="$HOME/dot-pi/workspaces/newsroom/$DATE"
mkdir -p "$WORKSPACE/research" "$WORKSPACE/sessions"

export AGENT_TEAM="newsroom"
export AGENT_WORKSPACE="$WORKSPACE"

echo "[newsroom] $(date '+%H:%M:%S') Starting daily briefing for $DATE"
echo "[newsroom] Workspace: $WORKSPACE"

pi \
  -p \
  --session-dir "$HOME/dot-pi/sessions" \
  -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
  --no-skills \
  --no-prompt-templates \
  "Today is $DATE. Workspace: $WORKSPACE

Produce today's news briefing by dispatching your team.

Step 1 — Dispatch both desks:

Dispatch desk-geopolitics: Today is $DATE. Workspace: $WORKSPACE. Scan the news landscape for significant geopolitics stories from the last 96 hours — US foreign policy, military intervention, sanctions, diplomacy, trade conflicts, alliances. Skim broadly with headline-only searches first, pick the most important stories, then go deeper. Hunt for primary sources. Write your draft to $WORKSPACE/desk-geopolitics-draft.md. If any story needs deep investigation, spawn a researcher and have them write to $WORKSPACE/research/.

Dispatch desk-scitech: Today is $DATE. Workspace: $WORKSPACE. Scan the news landscape for significant science and technology stories from the last 96 hours — ML/AI, robotics, space, US manufacturing, semiconductors, energy. Skim broadly with headline-only searches first, pick the most important stories, then go deeper. Hunt for primary sources. Write your draft to $WORKSPACE/desk-scitech-draft.md. If any story needs deep investigation, spawn a researcher and have them write to $WORKSPACE/research/.

Step 2 — After both desks finish, review their output. Check for gaps, missing stories, or weak sourcing. Dispatch follow-ups if needed.

Step 3 — Assemble a combined draft, then dispatch newsroom-copy-editor to produce the final report at $WORKSPACE/newsreport-$DATE.md."

echo "[newsroom] $(date '+%H:%M:%S') Done. Report: $WORKSPACE/newsreport-$DATE.md"
