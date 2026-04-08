---
description: Review the latest agent team run and suggest system improvements
---
Run a retrospective on the most recent agent team output. $@

## Step 1: Find the latest run

Use bash to find the most recent workspace run:

```
ls -t ~/dot-pi/workspaces/newsroom/ | head -1
```

Read all output files from that run directory: desk drafts, research files, the final report, and any sub-agent session files in the sessions/ subdirectory.

## Step 2: Assess output quality

Evaluate the final report and desk drafts on these dimensions:

- **Coverage:** Were the most important stories of the period captured? Any major gaps?
- **Sourcing:** How many stories cite primary sources vs only secondary reporting? Are citations valid?
- **Depth:** Were stories adequately investigated or just surface-level summaries?
- **Accuracy:** Any claims without attribution? Contradictions between sections?
- **Format:** Is the output well-structured, consistent, and readable?

## Step 3: Analyze agent behavior

If session files exist in the workspace sessions/ directory, read them to understand what each agent actually did:

- What search queries did desk agents run? Were they effective?
- How many SearXNG calls were made? Was there wasted effort (duplicate queries, irrelevant results)?
- Did agents write to disk as they went, or accumulate everything in context?
- Were researchers spawned? Did their output get incorporated well?
- How much context did each agent consume? (Look for usage fields in the session data)

## Step 4: Identify improvements

Based on your analysis, suggest specific, actionable changes to:

- **Agent prompts** — wording changes to agents/*.md that would improve output quality
- **Search strategy** — better approaches to query construction, category usage, pagination
- **Workflow** — changes to the dispatch sequence, agent roles, or handoff process
- **Context management** — ways to reduce context waste and keep agents focused
- **Coverage gaps** — topics or source types the agents should be instructed to check

## Step 5: Write the retrospective

Write your findings to the workspace run directory as `retro.md`:

```
# Retrospective — [DATE]

## Quality Assessment
[Ratings and notes per dimension]

## What Worked
[Specific things that went well]

## What Didn't
[Specific failures or weaknesses]

## Recommended Changes
[Numbered list of concrete modifications to agent prompts, workflow, or configuration]

## Metrics
- Stories covered: N
- Primary sources cited: N
- Search queries run: N
- Researchers spawned: N
- Context usage: [notes]
```
