# Subagents

Reusable dot-pi-style subagent configurations.

Each subagent is a small `PI_CODING_AGENT_DIR`-style directory. Parent agents make a subagent available by symlinking it into their local `agents/` directory:

```text
agents/deepresearch/agents/scout -> ../../../subagents/scout
```

## File Conventions

- `SYSTEM.md` defines the child agent's own behavior when it is invoked.
- `USAGE.md` defines the parent-facing invocation contract. The `agent-orchestrator` extension collages linked subagents' `USAGE.md` files into the parent system prompt.
- `pi-args` defines default CLI flags for the child agent.
- `skills/`, `prompts/`, `extensions/`, `themes/`, `models.json`, and `settings.json` are loaded as part of the child agent config directory.

Keep detailed execution instructions in `SYSTEM.md`. Keep `USAGE.md` concise: what the subagent does, when to use it, task shape, output contract, and sequencing notes.

Reusable subagents should generally set `--no-context-files` in `pi-args`. They are invoked inside parent workspaces and should not inherit unrelated repository context files such as `AGENTS.md` unless explicitly designed for codebase work.
