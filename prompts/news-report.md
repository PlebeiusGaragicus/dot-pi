---
description: Produce a daily news briefing via the newsroom agent team
---
Produce today's news briefing. $@

The workspace is available in your system prompt. Use `dispatch_agent` to run all six phases.

## Phase 1 — Reconnaissance

Dispatch **desk-geopolitics** with:
> SCAN MODE. Today is [DATE]. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to [WORKSPACE]/wire-geopolitics.md with YAML frontmatter (beat, date, queries_run, candidates). Include freshness and sourcing potential for each candidate. Return the list.

Dispatch **desk-scitech** with:
> SCAN MODE. Today is [DATE]. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to [WORKSPACE]/wire-scitech.md with YAML frontmatter (beat, date, queries_run, candidates). Include freshness and sourcing potential for each candidate. Return the list.

## Phase 2 — Editorial Selection

Review the wire scan results from both desks. Pick 5-8 stories total. For each, write a one-sentence assignment specifying the angle, expected sourcing, and a **slug** for the filename (e.g., `us-iran-ceasefire`). Flag any stories that need a researcher deep dive.

## Phase 3 — Deep Reporting

Dispatch **desk-geopolitics** with:
> INVESTIGATE MODE. Workspace: [WORKSPACE]. Cover these stories: [your assignments with slugs]. Write each story to [WORKSPACE]/stories/[slug].md with YAML frontmatter and a BLUF. Save source files to [WORKSPACE]/sources/ with frontmatter. Flag PDFs and image-heavy sources with has_pdf or has_images in source frontmatter.

Dispatch **desk-scitech** with the same structure for its assigned stories.

If you flagged stories for deep investigation, dispatch **newsroom-researcher** with the topic, specific questions, slug, and output path [WORKSPACE]/stories/[slug].md.

Review the summaries. Dispatch follow-ups if sourcing is weak.

## Phase 4 — Source Enrichment

Dispatch **newsroom-vlm** with:
> Process media sources in workspace [WORKSPACE]. Scan source files in [WORKSPACE]/sources/ for has_images: true or has_pdf: true. Download images, describe them, extract PDF text, and update the source files.

## Phase 5 — Verification

Dispatch **newsroom-fact-checker** with:
> Read all story files in [WORKSPACE]/stories/. Verify claims, check source URLs, cross-reference key assertions, verify BLUF accuracy. Write your report with YAML frontmatter to [WORKSPACE]/fact-check.md.

If critical issues are flagged, dispatch the relevant desk to fix the story.

## Phase 6 — Final Edit

Dispatch **newsroom-copy-editor** with:
> Read stories from [WORKSPACE]/stories/ and the fact-check report at [WORKSPACE]/fact-check.md. Assemble the final BLUF-structured report at [WORKSPACE]/newsreport-[DATE].md. Include a report-level BLUF, per-story BLUFs, and a consolidated Source Index. Date: [DATE]. Run ID: [RUN_ID from workspace directory name].
