#!/bin/bash
set -euo pipefail

source "$HOME/dot-pi/.env"

RUN_ID=$(date +%Y-%m-%d_%H%M)
DATE=$(date +%Y-%m-%d)
WORKSPACE="$HOME/dot-pi/workspaces/newsroom/$RUN_ID"
mkdir -p "$WORKSPACE/stories" "$WORKSPACE/sources" "$WORKSPACE/sources/images" "$WORKSPACE/sessions"

export AGENT_TEAM="newsroom"
export AGENT_WORKSPACE="$WORKSPACE"

echo "[newsroom] $(date '+%H:%M:%S') Starting daily briefing for $DATE"
echo "[newsroom] Workspace: $WORKSPACE"

pi \
  -p \
  --session "$WORKSPACE/session.jsonl" \
  -e "$HOME/dot-pi/extensions/orchestration/agent-team-2.ts" \
  --no-skills \
  --no-prompt-templates \
  "Today is $DATE. Workspace: $WORKSPACE. Run ID: $RUN_ID.

Produce today's news briefing by running all six phases.

Phase 1 — Reconnaissance:
Dispatch desk-geopolitics: SCAN MODE. Today is $DATE. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to $WORKSPACE/wire-geopolitics.md with YAML frontmatter (beat, date, queries_run, candidates). Include freshness and sourcing potential for each candidate. Return the list.
Dispatch desk-scitech: SCAN MODE. Today is $DATE. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to $WORKSPACE/wire-scitech.md with YAML frontmatter (beat, date, queries_run, candidates). Include freshness and sourcing potential for each candidate. Return the list.

Phase 2 — Editorial Selection:
Review the wire scans from both desks. Pick 5-8 stories total. For each, write a one-sentence assignment with the angle, expected sourcing, and a slug for the filename (e.g., us-iran-ceasefire). Flag any stories needing a researcher deep dive.

Phase 3 — Deep Reporting:
Dispatch desk-geopolitics: INVESTIGATE MODE. Workspace: $WORKSPACE. Cover these stories: [your assignments with slugs]. Write each story to $WORKSPACE/stories/[slug].md with YAML frontmatter and a BLUF. Save source files to $WORKSPACE/sources/ with frontmatter. Flag PDFs and image-heavy sources with has_pdf or has_images in source frontmatter.
Dispatch desk-scitech: INVESTIGATE MODE. Workspace: $WORKSPACE. Cover these stories: [your assignments with slugs]. Write each story to $WORKSPACE/stories/[slug].md with YAML frontmatter and a BLUF. Save source files to $WORKSPACE/sources/ with frontmatter. Flag PDFs and image-heavy sources with has_pdf or has_images in source frontmatter.
If any stories need deep investigation, dispatch newsroom-researcher with the topic, questions, slug, and output path $WORKSPACE/stories/[slug].md.
Review summaries. Dispatch follow-ups if sourcing is weak.

Phase 4 — Source Enrichment:
Dispatch newsroom-vlm: Process media sources in workspace $WORKSPACE. Scan source files in $WORKSPACE/sources/ for has_images: true or has_pdf: true. Download images, describe them, extract PDF text, and update the source files.

Phase 5 — Verification:
Dispatch newsroom-fact-checker: Read all story files in $WORKSPACE/stories/. Verify claims, check source URLs, cross-reference key assertions, verify BLUF accuracy. Write your report with YAML frontmatter to $WORKSPACE/fact-check.md.
If critical issues are flagged, dispatch the relevant desk to fix the story.

Phase 6 — Final Edit:
Dispatch newsroom-copy-editor: Read stories from $WORKSPACE/stories/ and the fact-check report at $WORKSPACE/fact-check.md. Assemble the final BLUF-structured report at $WORKSPACE/newsreport-$DATE.md. Include a report-level BLUF, per-story BLUFs, and a consolidated Source Index. Date: $DATE. Run ID: $RUN_ID."

echo "[newsroom] $(date '+%H:%M:%S') Done. Report: $WORKSPACE/newsreport-$DATE.md"
