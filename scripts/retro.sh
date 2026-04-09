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
export AGENT_WORKFLOW="retro"

echo "[retro] $(date '+%H:%M:%S') Target: $TARGET"
echo "[retro] Retro workspace: $RETRO_WORKSPACE"

pi -p \
  --session "$RETRO_WORKSPACE/session.jsonl" \
  -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
  --no-skills \
  --no-prompt-templates \
  "Run a retrospective on the agent team run."

echo "[retro] $(date '+%H:%M:%S') Done. Report: $RETRO_WORKSPACE/retro.md"
