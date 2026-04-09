---
description: Full six-phase newsroom briefing against saved topics
---
Produce today's news briefing. $@

The workspace and saved topics are available in your system prompt. Use `dispatch_agent` to run all six phases.

## Phase 1 — Reconnaissance

For each saved topic (check your system prompt for the list), dispatch **desk-reporter** in SCAN MODE:

> SCAN MODE. Today is [DATE]. Topic: [TOPIC_NAME] (slug: [SLUG]).
> Search queries: [QUERIES from topic config]. Categories: [CATEGORIES]. Time range: [TIME_RANGE].
> Developing stories to check for updates:
>   - [story slug] (last covered [DATE]): "[BLUF]"
> Write your wire to [WORKSPACE]/wire-[SLUG].md with YAML frontmatter (topic, date, queries_run, candidates). Include freshness and sourcing potential for each candidate. Return the list.

Process high-priority topics first. Batch conservatively (1-2 at a time) to conserve inference.

## Phase 2 — Editorial Selection

Review wire scan results from all topics. Pick 5-8 stories total based on significance, primary source availability, freshness, cross-topic balance, and continuity with developing stories. For each, write a one-sentence assignment specifying the angle, the **slug** for the filename, and which topic it belongs to. Flag stories needing a researcher deep dive.

## Phase 3 — Deep Reporting

For each topic that has assigned stories, dispatch **desk-reporter** in INVESTIGATE MODE:

> INVESTIGATE MODE. Workspace: [WORKSPACE]. Topic: [TOPIC_NAME] (slug: [SLUG]).
> Cover these stories: [assignments with slugs and angles].
> Dispatch newsroom-scraper for each source. Write stories to [WORKSPACE]/stories/[slug].md with YAML frontmatter and BLUF. Save sources to [WORKSPACE]/sources/. Flag PDFs and image-heavy sources in source frontmatter.

If you flagged stories for deep investigation, dispatch **newsroom-researcher** with the topic, specific questions, slug, and output path [WORKSPACE]/stories/[slug].md.

Review the summaries. Dispatch follow-ups if sourcing is weak.

## Phase 4 — Source Enrichment

Dispatch **newsroom-vlm** with:
> Process media sources in workspace [WORKSPACE]. Scan source files in [WORKSPACE]/sources/ for has_images: true or has_pdf: true. Download images, describe them, extract PDF text, and update the source files.

## Phase 5 — Verification

Dispatch **newsroom-fact-checker** with:
> Read all story files in [WORKSPACE]/stories/. Verify claims, check source URLs, cross-reference key assertions, verify BLUF accuracy. Write your report with YAML frontmatter to [WORKSPACE]/fact-check.md.

If critical issues are flagged, dispatch the relevant desk-reporter to fix the story.

## Phase 6 — Final Edit

Dispatch **newsroom-copy-editor** with:
> Read stories from [WORKSPACE]/stories/ and fact-check report at [WORKSPACE]/fact-check.md.
> Assemble the final BLUF-structured report at [WORKSPACE]/newsreport-[DATE].md with report-level BLUF, per-story BLUFs, and consolidated Source Index. Date: [DATE]. Run ID: [RUN_ID from workspace directory name].
> Also write [WORKSPACE]/story-index-update.yaml listing all stories from this run: slug, topic, status (developing/concluded), date, one-sentence BLUF per story. For stories that are continuations of developing stories from the story index, include a new timeline entry.
