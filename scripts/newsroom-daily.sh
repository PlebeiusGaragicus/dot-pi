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

echo "[newsroom-daily] $(date '+%H:%M:%S') Starting daily briefing for $DATE"

pi -p \
  --session "$WORKSPACE/session.jsonl" \
  -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
  --no-skills --no-prompt-templates \
  "Today is $DATE. Workspace: $WORKSPACE. Run ID: $RUN_ID.
Run the full newsroom workflow against all saved topics.
For each saved topic in your system prompt, dispatch desk-reporter in SCAN MODE with the topic's search queries, categories, and time range. Then select 5-8 stories, dispatch desk-reporter in INVESTIGATE MODE per topic, run fact-check, and produce the final report via newsroom-copy-editor.
The copy editor must also write $WORKSPACE/story-index-update.yaml listing all stories with slug, topic, status, date, and BLUF. Include timeline entries for developing stories."

[ -f "$WORKSPACE/story-index-update.yaml" ] && \
  cp "$WORKSPACE/story-index-update.yaml" "$TEAM_DIR/topics/story-index.yaml"

echo "[newsroom-daily] $(date '+%H:%M:%S') Done. Report: $WORKSPACE/newsreport-$DATE.md"
