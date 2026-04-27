# Subagent Concurrency

`agent-orchestrator` keeps the `parallel` tool shape for logically independent work, but physical execution is scheduled through resource pools.

This matters for self-hosted inference. Two different local subagents can still contend for the same GPU or local model server, so concurrency cannot be based only on the subagent name. It must be based on the shared resource the subagent consumes.

## Logical Parallelism vs Physical Concurrency

When an orchestrator submits a `tasks` batch, it is saying the tasks are independent and may be scheduled in parallel:

```json
{
  "tasks": [
    { "agent": "collector", "task": "Fetch source A" },
    { "agent": "collector", "task": "Fetch source B" }
  ]
}
```

`agent-orchestrator` decides how many actually run at once. With a `local=1` pool limit, these tasks queue and run one at a time even though the workflow remains logically parallel.

## Subagent Resource Pools

Each subagent can declare which shared resource pool it uses:

```text
subagents/collector/resource-pool.conf
```

```text
local
```

Missing or invalid `resource-pool.conf` defaults to `local` for self-hosted safety.

Current common pool names:

| Pool | Intended use |
|------|--------------|
| `local` | Self-hosted inference, local GPU, local model server |
| `api` | Hosted/datacenter API-backed agents |

Pool names are conventions. Add new names when a real shared resource needs its own limit.

## Global Pool Limits

Pool limits are configured at the dot-pi root:

```text
agent-orchestrator.conf
```

```ini
local=1
api=4
default=1
```

Rules:

- Missing config defaults to `local=1` and `default=1`.
- Missing pool limit uses `default`.
- Invalid limits are ignored.
- Limits less than `1` are ignored.

## Why Prompts Do Not Choose Concurrency

The LLM should express workflow independence, not infrastructure capacity. Prompts and tool calls can use `parallel` when tasks are independent. Capacity is controlled by subagent config (`resource-pool.conf`) and root config (`agent-orchestrator.conf`).

This keeps orchestration portable:

- Local deployments can keep `local=1`.
- API-backed deployments can raise `api`.
- The same subagent workflow continues to work without prompt changes.

## Result Ordering

Even when tasks run under different pool limits, results are returned in the same order as the submitted task list. This keeps downstream chain and summary behavior predictable.

