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

echo "[newsroom-weekly] $(date '+%H:%M:%S') Starting weekly overview for $DATE"

pi -p \
  --session "$WORKSPACE/session.jsonl" \
  -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
  --no-skills --no-prompt-templates \
  "Today is $DATE. Workspace: $WORKSPACE. Run ID: $RUN_ID.
Run the full newsroom workflow as a WEEKLY OVERVIEW.
Include ALL saved topics regardless of priority. For each topic, dispatch desk-reporter in SCAN MODE.
Select 8-12 stories for a broader weekly briefing. Add a 'Week in Review' section to the final report summarizing the week's major themes across all topics.
The copy editor must write $WORKSPACE/story-index-update.yaml listing all stories. Mark stories without new developments in 7+ days as dormant. Include timeline entries for developing stories."

[ -f "$WORKSPACE/story-index-update.yaml" ] && \
  cp "$WORKSPACE/story-index-update.yaml" "$TEAM_DIR/topics/story-index.yaml"

echo "[newsroom-weekly] $(date '+%H:%M:%S') Done. Report: $WORKSPACE/newsreport-$DATE.md"
