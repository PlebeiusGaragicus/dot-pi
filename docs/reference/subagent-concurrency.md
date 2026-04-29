# Subagent Concurrency

`agent-orchestrator` keeps the `parallel` tool shape for logically independent work, but physical execution is scheduled from the resolved model provider.

This matters for self-hosted inference. Two different local subagents can still contend for the same GPU or local model server, so concurrency cannot be based only on the subagent name. It must be based on whether the selected model provider is local or API-backed.

## Logical Parallelism vs Physical Concurrency

When an orchestrator submits a `tasks` batch, or emits multiple independent `subagent` tool calls, it is saying the tasks are independent and may be scheduled in parallel:

```json
{
  "tasks": [
    { "agent": "collector", "task": "Fetch source A" },
    { "agent": "collector", "task": "Fetch source B" }
  ]
}
```

`agent-orchestrator` decides how many actually run at once. If both tasks resolve to a provider listed in `local-providers.conf`, and `local=1`, they queue and run one at a time inside the orchestrator process even though the workflow remains logically parallel. If they resolve to an API-backed provider, they are spawned without local throttling.

## Provider Classification

Local providers are configured at the dot-pi root:

```text
local-providers.conf
```

```text
# Providers backed by limited local or self-hosted compute.
plebchat
```

Any provider not listed is treated as API-backed and unbounded. If `local-providers.conf` is missing, `plebchat` is treated as local by default.

Subagents do not declare pools directly. They declare model intent through `pi-args`:

```text
--model
$DEFAULT_VLM_MODEL
```

Model selection is resolved the same way it is for launch: explicit model flags, inline environment overrides, agent-local `.model`, repo-local `model-defaults`, and then pi settings fallback. `agent-orchestrator` derives the provider from the resolved `provider/model` string. If no model flag resolves, it uses `shared/settings.json`'s `defaultProvider`.

## Local Limits

Local concurrency limits are configured at the dot-pi root:

```text
agent-orchestrator.conf
```

```ini
local=1
default=1
```

Rules:

- Missing config defaults to `local=1` and `default=1`.
- Invalid limits are ignored.
- Limits less than `1` are ignored.

Local limits are enforced in-process by the active `agent-orchestrator` extension. This means all local-provider subagent launches from one running orchestrator share the same local queue, regardless of whether they came from a single call, a `tasks` batch, a chain step, or multiple separate tool calls in the same assistant turn.

## Why Prompts Do Not Choose Concurrency

The LLM should express workflow independence, not infrastructure capacity. Prompts and tool calls can use `parallel` when tasks are independent. Capacity is controlled by model choice, `local-providers.conf`, and `agent-orchestrator.conf`.

This keeps orchestration portable:

- Local deployments can keep `local=1`.
- API-backed deployments are not throttled by local provider limits.
- The same subagent workflow continues to work without prompt changes.

## Result Ordering

Even when tasks run under different pool limits, results are returned in the same order as the submitted task list. This keeps downstream chain and summary behavior predictable.

