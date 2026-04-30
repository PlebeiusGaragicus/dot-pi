# Multi-Agent Systems

This is the definitive guide to dot-pi's multi-agent implementation. For the file-by-file anatomy of an agent config root, start with [Agent Layout](../agent-layout.md). This page explains how those files work together to create an orchestrated multi-agent system.

In dot-pi, a multi-agent system (MAS) is a top-level orchestrator agent plus a pool of specialized subagents. The orchestrator owns the user conversation, decomposes work, calls subagents through the `subagent` tool, and synthesizes the final answer. Subagents run as isolated pi child processes with their own context windows, tools, prompts, and model settings.

This is a centralized orchestration model. It is closer to supervisor-worker and pipeline systems than to fully decentralized swarms.

## Implementation Overview

A MAS is a normal agent config root with one important extension:

```text
agents/deepresearch/
├── SYSTEM.md
├── pi-args
├── bootstrap.sh
├── extensions/
│   ├── agent-orchestrator -> ../../../shared/extensions/agent-orchestrator
│   └── reasoning-off-shim -> ../../../shared/extensions-common/reasoning-off-shim
└── agents/
    └── scout/
        ├── README.md
        ├── SYSTEM.md
        ├── USAGE.md
        ├── pi-args
        └── extensions/
            └── reasoning-off-shim -> ../../../../../shared/extensions-subagents/reasoning-off-shim
```

The parent process loads `extensions/agent-orchestrator`, which registers the `subagent` tool. When the model calls that tool, the extension launches child pi processes using the selected subagent directories as their `PI_CODING_AGENT_DIR` roots.

Each subagent is isolated:

- It has its own prompt files.
- It has its own `pi-args`.
- It has its own tools and skills.
- It has its own context window.
- It only gets the task passed to it by the orchestrator.

This isolation is the main reason to use a MAS. Subagents can explore, write, review, OCR, collect, or evaluate without filling the parent context with every intermediate detail.

## Terminology Map

| MAS literature | dot-pi artifact |
|----------------|-----------------|
| Orchestrator, supervisor, controller | `agents/<name>/SYSTEM.md` plus `agent-orchestrator` |
| Worker, specialist, role agent | A subagent config under `agents/<name>/agents/` |
| Agent capability card | `README.md` and `USAGE.md` in a subagent config |
| Blackboard or shared workspace | Workspace directory and artifact files such as `sources/` or `report.md` |
| Tool restriction | Subagent-specific `pi-args`, skills, and extensions |
| Evaluation agent | A reviewer, editor, scanner, auditor, or retro subagent |
| Resource scheduler | subagent `pi-args`, `local-providers.conf`, and `agent-orchestrator.conf` |

## Orchestrator Root

The orchestrator root is the command the user runs. It should define the workflow and delegation policy, not duplicate every subagent's detailed instructions.

Key files:

- `SYSTEM.md`: parent prompt. Put workflow policy, delegation rules, artifact expectations, resume behavior, and final response style here.
- `pi-args`: parent tool restrictions and model defaults. MAS roots usually need the `subagent` tool plus enough read/list/search capability to inspect workspace artifacts.
- `extensions/agent-orchestrator`: registers the `subagent` tool and handles discovery, prompt augmentation, scheduling, and child process launches.
- `bootstrap.sh`: optional, but common for MAS configs that create durable artifacts. `WORKSPACE_AGENT=1` enables workspace mode; the script can create directories, export environment variables, initialize daemons, and run preflight checks before pi starts. Its stdout/stderr is captured in `BOOTSTRAP_LOG`.

The optional repo-level `agent-orchestrator.conf` file configures local-provider limits for physical subagent concurrency.

The orchestrator should normally coordinate rather than perform specialist work itself. If a task belongs to a subagent role, encode that policy in the root `SYSTEM.md`.

## Subagent Config Format

Subagents are pi config directories stored in two places:

- User-level: `<PI_CODING_AGENT_DIR>/agents/`
- Project-level: `.pi/agents/`, discovered from the current working directory upward

Reusable dot-pi subagents live canonically under `subagents/<name>/` and are symlinked into a MAS, for example `agents/deepresearch/agents/scout -> ../../../subagents/scout`. MAS-specific subagents can be real directories directly under `agents/<mas>/agents/<name>/`.

A subagent is available when its directory contains `SYSTEM.md` or `APPEND_SYSTEM.md`.

Recommended files:

- `SYSTEM.md` or `APPEND_SYSTEM.md`: the subagent prompt.
- `README.md`: short description used in orchestrator listings.
- `USAGE.md`: invocation contract appended to the orchestrator prompt.
- `pi-args`: tool, model, context-file, and skill restrictions for this subagent.
- `extensions/reasoning-off-shim`: linked from `shared/extensions-subagents/` because every subagent is its own pi config root.

Subagents do not get the top-level common extension bundle. They are non-interactive child processes, so only extensions in `shared/extensions-subagents/` are wired into them by `dotpi sync`. For reusable symlinked subagents, `sync` wires the canonical `subagents/<name>/` directory rather than treating the MAS link as the source of truth.

The `USAGE.md` file is especially important. It tells the orchestrator how to call the subagent, what input the subagent expects, what artifacts it may read or write, and what it should return.

Example:

```markdown
# scout Usage

Call scout when you need fast codebase or source discovery.

Input:
- A focused research question.
- Any known paths or keywords.

Output:
- Concise findings with file paths or source paths.
- Open questions or blockers.
- Do not make edits.
```

## Prompt Augmentation

The parent MAS prompt lives in `<agentDir>/SYSTEM.md`. At runtime, `agent-orchestrator` appends discovered subagent information so the orchestrator can delegate without hard-coding every subagent contract into the parent prompt.

The appended information includes:

- subagent names
- short descriptions from `README.md`
- invocation contracts from `USAGE.md`

This keeps the root `SYSTEM.md` focused on orchestration policy while each subagent owns its own capability contract.

## Agent Discovery

Agents are discovered fresh on each `subagent` tool invocation.

Discovery locations:

1. User-level subagents from `<PI_CODING_AGENT_DIR>/agents/`
2. Project-level subagents from `.pi/agents/`, relative to the current working directory and walking upward

The `agentScope` parameter controls which locations are loaded:

- `user`: only the MAS config's bundled subagents
- `project`: only project-local `.pi/agents/`
- `both`: both sets, with project agents overriding user agents of the same name

Project-local agents are useful when a repository needs task-specific specialists without changing the shared dot-pi config.

## The `subagent` Tool

The `subagent` tool has three modes: single, parallel, and chain.

### Single

Run one subagent on one task:

```json
{ "agent": "scout", "task": "Find all auth code" }
```

Use this for routing or one-off specialist work.

### Parallel

Run logically independent tasks:

```json
{
  "tasks": [
    { "agent": "scout", "task": "Find authentication code" },
    { "agent": "planner", "task": "Review architecture boundaries" }
  ]
}
```

The tasks are independent from the prompt's point of view. Physical concurrency is still controlled by provider-derived scheduling.

### Chain

Run a sequential pipeline:

```json
{
  "chain": [
    { "agent": "scout", "task": "Find code related to auth" },
    { "agent": "planner", "task": "Plan changes based on: {previous}" }
  ]
}
```

The `{previous}` placeholder is replaced with the prior step's output. Use chains for fixed pipelines where each step depends on the one before it.

## Resource Scheduling

The LLM expresses logical independence; config controls physical concurrency. Subagents declare model intent with `pi-args`:

```text
agents/<mas>/agents/<subagent>/pi-args
```

```text
--model
$DEFAULT_AGENTIC_MODEL
```

Providers backed by limited local or self-hosted compute are listed at the dot-pi root:

```text
local-providers.conf
```

```text
lmstudio
```

Local limits are configured at the dot-pi root:

```text
agent-orchestrator.conf
```

```ini
local=1
default=1
```

This matters most for self-hosted inference. Ten OCR tasks may be logically independent, but if they all resolve to a provider listed in `local-providers.conf`, the local limit should probably run them one at a time. API-backed providers are treated as unbounded and are not throttled by the local limit.

For the exact rules, see [Subagent Concurrency](subagent-concurrency.md).

## Workspace And Artifact Handoffs

MAS configs often run in workspace mode. A workspace gives all subagents a shared filesystem for durable artifacts:

```text
workspaces/deepresearch/2026-04-28-120000/
├── sources/
├── drafts/
├── sessions/
└── report.md
```

Artifact handoffs are usually better than returning large text blobs through the orchestrator. A collector can save source extracts to `sources/`, a writer can read those files and create `drafts/report.md`, and an editor can review the draft against the saved sources.

This pattern keeps the parent context smaller and makes failures inspectable. It also makes `resume` and retrospective analysis practical.

## Common Patterns

### Orchestrator-Worker

A parent agent plans work, dispatches specialized subagents, and integrates their outputs. This is dot-pi's default MAS shape and matches the pattern described in Anthropic's “Building Effective Agents” and “How we built our multi-agent research system.”

Use it when tasks benefit from separate contexts, parallel exploration, or specialized tool access.

### Router

A parent agent classifies the request and sends it to one specialist. This is useful for support, search, coding, or documentation assistants where each request has one obvious owner.

### Fixed Pipeline

Agents run in a known sequence: scout, collect, write, edit; or implement, review, revise. Pipelines are easier to evaluate than open-ended delegation because the expected artifacts and handoffs are explicit.

### Evaluator-Optimizer

One agent produces an output and another evaluates it against criteria. The producer revises until quality is acceptable or a budget is exhausted. This pattern is useful for writing, code review, factuality checks, and policy-sensitive outputs.

### Debate And Reflection

Multiple agents produce competing analyses or critiques before the orchestrator decides. Related methods include Reflexion, multi-agent debate, Tree of Thoughts, and self-consistency. Use these when independent reasoning paths are valuable, but cap iterations to avoid runaway cost.

### Blackboard / Artifact Handoff

Agents communicate through files in the workspace instead of passing long text through the orchestrator context. This keeps the parent context small and makes failures inspectable.

### Swarm / Decentralized Coordination

Swarms let agents coordinate peer-to-peer through shared memory or task queues. dot-pi does not currently implement this as a first-class pattern; use an orchestrator unless there is a strong reason to give agents autonomous coordination.

## Best Practices

- Give each subagent a narrow responsibility, explicit tools, and a short invocation contract in `USAGE.md`.
- Put workflow policy in the orchestrator `SYSTEM.md`, not in every subagent.
- Prefer artifact handoffs for large outputs. Return concise status from subagents and write durable deliverables to the workspace.
- Restrict capabilities structurally through tools, skills, and config. Do not rely only on prompt instructions for safety boundaries.
- Use `parallel` only for logically independent work. Let `agent-orchestrator` provider-derived scheduling decide physical concurrency.
- Add evaluator subagents for high-risk outputs: citations, code changes, factual claims, security findings, or final reports.
- Keep session logs and manifests. Traceability is what makes MAS failures debuggable.
- Evaluate workflows with scripted prompts before tuning prompts by feel.

## Known Failure Modes

- The orchestrator performs specialist work itself instead of delegating.
- Subagents return huge summaries instead of writing artifacts.
- Parallel calls contend for the same local model server or GPU.
- The system lacks a verifier, so hallucinated or incomplete outputs pass through.
- Agents loop because the stop condition, artifact path, or ownership boundary is unclear.
- The orchestrator treats a failed subagent as a partial success.
- `USAGE.md` drifts from the subagent's real behavior, so the orchestrator calls it incorrectly.
- A subagent is missing required extensions or `pi-args` because it was assumed to inherit the parent MAS root.

## How This Maps To dot-pi

Start with a simple orchestrator-worker design. Add pipelines when the workflow is stable, evaluator agents when quality matters, and provider-derived scheduling when concurrency meets real infrastructure limits. Reach for more experimental patterns like debate or swarm coordination only after the basic artifact flow and eval loop are reliable.

Use [Agent Layout](../agent-layout.md) as the source of truth for where files live. Use this page as the source of truth for how the orchestrator and subagents interact.

## Resources

- Anthropic, [Building Effective Agents](https://www.anthropic.com/engineering/building-effective-agents/): practical patterns including prompt chaining, routing, parallelization, orchestrator-workers, and evaluator-optimizer loops.
- Anthropic, [How we built our multi-agent research system](https://www.anthropic.com/engineering/built-multi-agent-research-system): production lessons for breadth-first research with a lead agent and parallel subagents.
- Anthropic, [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents): how to evaluate agentic systems beyond single-response benchmarks.
- OpenAI Agents SDK, [Multi-agent orchestration](https://openai.github.io/openai-agents-js/guides/multi-agent): handoffs, agents as tools, and orchestration tradeoffs.
- AutoGen: conversation-driven multi-agent programming framework.
- CAMEL: role-playing agent collaboration framework.
- MetaGPT and ChatDev: software-development MAS examples with role specialization and staged workflows.
- AgentVerse: framework for multi-agent task solving and simulation.
- Reflexion: actor-evaluator-reflector pattern for verbal self-improvement.
- Tree of Thoughts and multi-agent debate: search and deliberation methods for difficult reasoning tasks.
- “Large Language Model based Multi-Agents: A Survey of Progress and Challenges” (2024): survey of LLM MAS domains, communication, profiling, and evaluation.
- “A Survey on Multi-Generative Agent System: Recent Advances and New Frontiers” (2024): survey of generative MAS applications and evaluation.
