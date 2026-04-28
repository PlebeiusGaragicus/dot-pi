# Agent Prompt Extension

Optional standalone-agent prompt frontmatter. Reads `AGENT.md` from the agent directory at startup and uses it to configure tools, model, and the system prompt.

## Files

- `index.ts` -- Reads `AGENT.md`, parses YAML frontmatter, wires hooks

## Configuration

Place an `AGENT.md` next to the agent's `extensions/` folder:

```markdown
---
tools: read, grep, find, ls, bash
model: anthropic/claude-sonnet-4-5
---

You are a focused research assistant. Always cite sources.
```

- `tools` -- comma-separated list of tool names; applied via `pi.setActiveTools()` on `session_start`
- `model` -- `<provider>/<modelId>`; resolved via `ctx.modelRegistry.find()` and applied via `pi.setModel()` on `session_start`
- Markdown body -- appended to the system prompt via `before_agent_start`

All three sections are optional. A missing `AGENT.md` is a no-op.

## Hooks Registered

- `session_start` -- applies `tools` and `model` from frontmatter
- `before_agent_start` -- appends the body to the system prompt

## Related Docs

- [Standalone Agents](https://PlebeiusGaragicus.github.io/dot-pi/standalone-agents/)
- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
