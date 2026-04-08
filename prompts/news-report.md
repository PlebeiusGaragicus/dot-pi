---
description: Produce a daily news briefing via the newsroom agent team
---
Produce today's news briefing. $@

The workspace is available in your system prompt. Use `dispatch_agent` to run all five phases.

## Phase 1 — Reconnaissance

Dispatch **desk-geopolitics** with:
> SCAN MODE. Today is [DATE]. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to [WORKSPACE]/wire-geopolitics.md. Return the list.

Dispatch **desk-scitech** with:
> SCAN MODE. Today is [DATE]. Scan your beat for significant stories from the last 96 hours. Write your ranked candidate list to [WORKSPACE]/wire-scitech.md. Return the list.

## Phase 2 — Editorial Selection

Review the wire scan results from both desks. Pick 5-8 stories total. For each, write a one-sentence assignment specifying the angle and expected sourcing. Flag any stories that need a researcher deep dive.

## Phase 3 — Deep Reporting

Dispatch **desk-geopolitics** with:
> INVESTIGATE MODE. Workspace: [WORKSPACE]. Cover these stories: [your assignments]. Write each story to [WORKSPACE]/stories/[slug].md. Save raw sources to [WORKSPACE]/sources/.

Dispatch **desk-scitech** with the same structure for its assigned stories.

If you flagged stories for deep investigation, dispatch **newsroom-researcher** with the topic, specific questions, and output path [WORKSPACE]/research/[slug].md.

Review the summaries. Dispatch follow-ups if sourcing is weak.

## Phase 4 — Verification

Dispatch **newsroom-fact-checker** with:
> Read all story files in [WORKSPACE]/stories/. Verify claims, check source URLs, cross-reference key assertions. Write your report to [WORKSPACE]/fact-check.md.

If critical issues are flagged, dispatch the relevant desk to fix the story.

## Phase 5 — Final Edit

Dispatch **newsroom-copy-editor** with:
> Read stories from [WORKSPACE]/stories/ and the fact-check report at [WORKSPACE]/fact-check.md. Assemble the final report at [WORKSPACE]/newsreport-[DATE].md.
