---
description: Writer drafts, editor reviews, writer applies feedback
---
Use the subagent tool with the chain parameter to execute this workflow:

1. First, use the "writer" agent to draft a blog post about: $@
2. Then, use the "editor" agent to review the draft from the previous step (use {previous} placeholder)
3. Finally, use the "writer" agent to apply the editorial feedback from the review (use {previous} placeholder)

Execute this as a chain, passing output between steps via {previous}.
