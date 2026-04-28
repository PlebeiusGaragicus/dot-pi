# Agent Orchestrator Extension

The `agent-orchestrator` extension registers a `subagent` tool that spawns isolated pi child processes, each with its own context window and config root.

Source: `shared/extensions/agent-orchestrator/`

## Subagent Config Format

Subagents are pi config directories stored in `<agentDir>/agents/` or discovered from project-local `.pi/agents/`:

```text
agents/deepresearch/
├── SYSTEM.md
├── extensions/
├── agents/
│   └── scout/
│       ├── SYSTEM.md
│       ├── USAGE.md
│       └── resource-pool.conf
└── workspace.conf
```

Each subagent directory must contain `SYSTEM.md` or `APPEND_SYSTEM.md`. Optional files:

- `README.md` supplies the short description shown to the orchestrator.
- `USAGE.md` supplies the invocation contract appended to the orchestrator prompt.
- `resource-pool.conf` names the shared concurrency pool used by the subagent.

## Tool Modes

### Single

```json
{ "agent": "scout", "task": "Find all auth code" }
```

### Parallel

```json
{
  "tasks": [
    { "agent": "scout", "task": "Find auth code" },
    { "agent": "planner", "task": "Review architecture" }
  ]
}
```

Tasks are logically independent. Physical concurrency is scheduled through resource pools; see [Subagent Concurrency](subagent-concurrency.md).

### Chain

```json
{
  "chain": [
    { "agent": "scout", "task": "Find code related to auth" },
    { "agent": "planner", "task": "Plan changes based on: {previous}" }
  ]
}
```

Sequential pipeline. `{previous}` is replaced with the prior step's output.

## Orchestrator Prompt

The parent MAS prompt lives in `<agentDir>/SYSTEM.md`. Use it to define the workflow, delegation policy, expected artifacts, and final response style.

The extension appends discovered subagent names, descriptions, resource pools, and `USAGE.md` contracts so the orchestrator can delegate without hard-coding every call shape.

## Agent Discovery

Agents are discovered fresh on each tool invocation from two locations:

1. **User-level**: `<PI_CODING_AGENT_DIR>/agents/`
2. **Project-level**: `.pi/agents/` (relative to cwd, walking up)

The `agentScope` parameter controls which are loaded (`"user"`, `"project"`, or `"both"`). Project agents override user agents with the same name when scope is `"both"`.
