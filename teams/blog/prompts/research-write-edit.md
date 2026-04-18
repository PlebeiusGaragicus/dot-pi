---
description: Full blog workflow - researcher gathers material, writer drafts, editor polishes
---
Use the subagent tool with the chain parameter to execute this workflow:

1. First, use the "researcher" agent to gather all relevant information about: $@
2. Then, use the "writer" agent to draft a blog post using the research from the previous step (use {previous} placeholder)
3. Finally, use the "editor" agent to review and polish the draft from the previous step (use {previous} placeholder)

Execute this as a chain, passing output between steps via {previous}.
