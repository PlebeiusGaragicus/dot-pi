#!/bin/bash
set -euo pipefail
source "$HOME/dot-pi/.env"

RUN_ID=$(date +%Y-%m-%d_%H%M)
DATE=$(date +%Y-%m-%d)
TEAM_DIR="$HOME/dot-pi/workspaces/newsroom"
WORKSPACE="$TEAM_DIR/$RUN_ID"
mkdir -p "$WORKSPACE/stories" "$WORKSPACE/sources" "$WORKSPACE/sources/images" "$WORKSPACE/sessions" \
         "$TEAM_DIR/topics"

export AGENT_TEAM="newsroom"
export AGENT_WORKSPACE="$WORKSPACE"
export AGENT_WORKFLOW="news-report"

echo "[newsroom-daily] $(date '+%H:%M:%S') Starting daily briefing for $DATE"

pi -p \
  --session "$WORKSPACE/session.jsonl" \
  -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
  --no-skills --no-prompt-templates \
  "Produce today's news briefing. Today is $DATE. Run ID: $RUN_ID."

[ -f "$WORKSPACE/story-index-update.yaml" ] && \
  cp "$WORKSPACE/story-index-update.yaml" "$TEAM_DIR/topics/story-index.yaml"

echo "[newsroom-daily] $(date '+%H:%M:%S') Done. Report: $WORKSPACE/newsreport-$DATE.md"
