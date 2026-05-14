# Multi-Agent Systems

This page describes how dot-pi implements **multi-agent systems (MAS)** today. For per-file layout of an agent config root, see [Agent Layout](../agent-layout.md). For the top-level orchestrator design rationale, see [Top-Level Agent MAS](../design/top-level-agent-mas.md).

In dot-pi, a MAS is a **top-level orchestrator** agent (for example `mas`) plus a **fixed set of capability workers** (`ask`, `scout`, `writer`, `coder`, `web`). Each worker is its own shipped `PI_CODING_AGENT_DIR` under `agents/<worker>/`. The orchestrator owns the user conversation, calls workers through the **`subagent`** tool registered by **`top-level-agent-orchestrator`**, and synthesizes the final answer. Workers run as isolated `pi` child processes with their own prompts, `pi-args`, tools, and context.

## Implementation overview

```text
agents/mas/
├── SYSTEM.md
├── pi-args
├── extensions/
│   ├── ...                    # shipped common extensions (see shared/shipped-common-extensions)
│   └── top-level-agent-orchestrator -> ../../../shared/extensions/top-level-agent-orchestrator
└── prompts/
    └── ...
```

The extension registers the **`subagent`** tool with modes `single`, `parallel` (via `tasks`), and `chain`. Each invocation resolves worker names to `agents/<worker>/` under the dot-pi package root (`DOT_PI_DIR`), sets `PI_CODING_AGENT_DIR` for the child, and passes worker traces under `$DOT_PI_OVERLAY/<mas>/subagent-traces/<run-id>/` as `--session-dir`.

Workers are **not** discovered from `agents/<mas>/agents/` and postinstall does not wire nested pools.

## Terminology map

| MAS literature | dot-pi artifact |
|----------------|-----------------|
| Orchestrator, supervisor | `agents/<mas>/SYSTEM.md` plus **`top-level-agent-orchestrator`** |
| Worker, specialist | Top-level `agents/<worker>/` (`ask`, `scout`, `writer`, `coder`, `web`) |
| Capability card | `CAPABILITY.md`, `README.md`, `USAGE.md` under each worker |
| Shared workspace | Current working directory (in-situ) and project files |
| Tool restriction | Per-worker `pi-args`, skills, extensions |

## Orchestrator root

- **`SYSTEM.md`**: delegation policy, artifact expectations, and how to use slash prompts under `prompts/`.
- **`pi-args`**: parent model and tool allowlists for the orchestrator process.
- **`extensions/top-level-agent-orchestrator`**: registers `subagent`, appends worker catalog text, launches children, writes trace manifests.
- **`prompts/`**: workflow templates (`/deepresearch`, `/pdf-ocr`, etc.) that orchestrate workers.

## The `subagent` tool

Same three modes as implemented in `shared/extensions/top-level-agent-orchestrator/index.ts`:

### Single

```json
{ "agent": "scout", "task": "Find all auth code" }
```

### Parallel

```json
{
  "tasks": [
    { "agent": "scout", "task": "Find authentication code" },
    { "agent": "web", "task": "Find primary sources for …" }
  ]
}
```

Parallel fan-out is bounded by the extension’s concurrency cap (`MAX_PARALLEL_TASKS` in source). Each worker’s **tools** and other CLI flags come from that worker’s **`pi-args`**; the **model** is pi’s active default from **`shared/settings.json`** (pi updates that file when the user changes the model) unless that worker’s **`pi-args`** includes **`--model provider/id`**.

When the resolved provider for a worker is **LM Studio** (`lmstudio`) or **Ollama** (`ollama`), the extension also applies a separate shared cap on concurrent child `pi` processes (default **one**), so parallel `tasks[]` may wait for a slot even under the global task limit. Resolution uses the worker’s first `--model` value (`provider/model` prefix) when **`pi-args`** includes one, otherwise **`defaultProvider`** from `shared/settings.json` (including a bare id such as `lmstudio`). Other providers are not throttled this way; raise the limit in source (`LOCAL_INFERENCE_PARALLEL_LIMIT`) if your machine can sustain more concurrent local loads.

### Chain

```json
{
  "chain": [
    { "agent": "scout", "task": "Find code related to auth" },
    { "agent": "writer", "task": "Draft a short note from: {previous}" }
  ]
}
```

`{previous}` is replaced with the prior step’s final assistant text.

## Optional project-local pi configs

Pi can still load **project-local** agent directories under `.pi/agents/` for non–dot-pi-managed flows. dot-pi **postinstall/relink** does not symlink extensions into those paths; manage them manually if you use them alongside dot-pi.

## Workflow authoring and capability boundaries

Workflow prompts must respect each worker’s **structural** configuration (`pi-args`, skills, extensions). Prompts cannot grant tools the worker does not have.

Before drafting a `subagent` call, read the worker’s `CAPABILITY.md` / `USAGE.md` and `pi-args`:

- Paths and URLs require workers with `read`, `bash`, or appropriate skills.
- Artifacts require `write`/`edit` where applicable.
- No-tool workers such as `ask` need the evidence inlined in the task string.

See the [Workflow Writing Guide](../workflow-writing-guide.md) for a checklist.

## Workspace and artifact handoffs

MAS runs **in-situ** in the user’s cwd. Prefer files (`sources/`, `drafts/`, `reports/`) over huge inline returns so the orchestrator context stays small and runs remain auditable.

## Common patterns

Patterns (orchestrator–worker, router, pipeline, evaluator–optimizer, artifact handoff) are unchanged in principle; the implementation detail is that **workers are always the five top-level capability agents** unless you fork the extension.

## Best practices

- Put orchestration policy in `agents/<mas>/SYSTEM.md`; keep worker roots focused on their role.
- Match every delegated task to the worker’s real tools and `pi-args`.
- Prefer artifact handoffs for large outputs; keep worker replies concise.
- Use parallel mode only when tasks are logically independent; respect the extension’s concurrency cap and your own provider rate limits.
- Keep trace directories under `$DOT_PI_OVERLAY` for postmortems.

## Known failure modes

- Orchestrator does specialist work instead of delegating.
- Workers return huge summaries instead of writing artifacts.
- Parallel calls overload a single local model endpoint.
- Missing verifier for high-risk outputs.
- `CAPABILITY.md` / `USAGE.md` drift from real worker behavior.

## Resources

- Anthropic, [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents/)
- Anthropic, [How we built our multi-agent research system](https://www.anthropic.com/engineering/built-multi-agent-research-system)
- [Top-Level Agent MAS](../design/top-level-agent-mas.md) in this repo
