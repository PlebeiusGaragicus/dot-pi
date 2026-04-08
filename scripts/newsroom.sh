#!/bin/bash
set -euo pipefail

source "$HOME/dot-pi/.env"

DATE=$(date +%Y-%m-%d)
WORKSPACE="$HOME/dot-pi/workspaces/newsroom/$DATE"
mkdir -p "$WORKSPACE/stories" "$WORKSPACE/research" "$WORKSPACE/sources" "$WORKSPACE/sessions"

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

Produce today's news briefing by running all five phases.

Phase 1 — Reconnaissance:
Dispatch desk-geopolitics: SCAN MODE. Today is $DATE. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to $WORKSPACE/wire-geopolitics.md. Return the list.
Dispatch desk-scitech: SCAN MODE. Today is $DATE. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to $WORKSPACE/wire-scitech.md. Return the list.

Phase 2 — Editorial Selection:
Review the wire scans from both desks. Pick 5-8 stories total. For each, write a one-sentence assignment with the angle and expected sourcing. Flag any stories needing a researcher deep dive.

Phase 3 — Deep Reporting:
Dispatch desk-geopolitics: INVESTIGATE MODE. Workspace: $WORKSPACE. Cover the stories you assigned. Write each to $WORKSPACE/stories/[slug].md. Save raw sources to $WORKSPACE/sources/.
Dispatch desk-scitech: INVESTIGATE MODE. Workspace: $WORKSPACE. Cover the stories you assigned. Write each to $WORKSPACE/stories/[slug].md. Save raw sources to $WORKSPACE/sources/.
If any stories need deep investigation, dispatch newsroom-researcher with the topic, questions, and output path $WORKSPACE/research/[slug].md.
Review summaries. Dispatch follow-ups if sourcing is weak.

Phase 4 — Verification:
Dispatch newsroom-fact-checker: Read all story files in $WORKSPACE/stories/. Verify claims, check source URLs, cross-reference key assertions. Write your report to $WORKSPACE/fact-check.md.
If critical issues are flagged, dispatch the relevant desk to fix the story.

Phase 5 — Final Edit:
Dispatch newsroom-copy-editor: Read stories from $WORKSPACE/stories/ and the fact-check report at $WORKSPACE/fact-check.md. Assemble the final polished report at $WORKSPACE/newsreport-$DATE.md."

echo "[newsroom] $(date '+%H:%M:%S') Done. Report: $WORKSPACE/newsreport-$DATE.md"
