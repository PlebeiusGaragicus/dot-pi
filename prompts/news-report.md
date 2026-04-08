---
description: Produce a daily news briefing via the newsroom agent team
---
Produce today's news briefing. $@

First, use bash to determine today's date and set up the workspace:

```
DATE=$(date +%Y-%m-%d)
WORKSPACE="$HOME/dot-pi/workspaces/newsroom/$DATE"
mkdir -p "$WORKSPACE/research" "$WORKSPACE/sessions"
```

Then dispatch your team following this plan:

## Step 1: Dispatch both desks

**Dispatch desk-geopolitics** with this task:
Run `date +%Y-%m-%d` to get today's date. The workspace is ~/dot-pi/workspaces/newsroom/$DATE/. Scan the news landscape for significant geopolitics stories from the last 96 hours — US foreign policy, military intervention, sanctions, diplomacy, trade conflicts, alliances. Skim broadly with headline-only searches first, pick the most important stories, then go deeper on each. Hunt for primary sources. Write your draft to ~/dot-pi/workspaces/newsroom/$DATE/desk-geopolitics-draft.md. If any story needs deep investigation, spawn a researcher and have them write to ~/dot-pi/workspaces/newsroom/$DATE/research/.

**Dispatch desk-scitech** with this task:
Run `date +%Y-%m-%d` to get today's date. The workspace is ~/dot-pi/workspaces/newsroom/$DATE/. Scan the news landscape for significant science and technology stories from the last 96 hours — ML/AI, robotics, space, US manufacturing, semiconductors, energy. Skim broadly with headline-only searches first, pick the most important stories, then go deeper on each. Hunt for primary sources. Write your draft to ~/dot-pi/workspaces/newsroom/$DATE/desk-scitech-draft.md. If any story needs deep investigation, spawn a researcher and have them write to ~/dot-pi/workspaces/newsroom/$DATE/research/.

## Step 2: Review

Review the output from both desks. Are there major gaps? Weak sourcing? Missing angles? If so, dispatch follow-ups.

## Step 3: Copy-edit

Dispatch newsroom-copy-editor with this task:
Read the desk drafts from ~/dot-pi/workspaces/newsroom/$DATE/ (run `date +%Y-%m-%d` to get the date). Review for citation accuracy, duplicate stories, formatting consistency, and unsupported claims. Produce the final polished report at ~/dot-pi/workspaces/newsroom/$DATE/newsreport-$DATE.md.
