# Multi-Agent Systems

In dot-pi, a multi-agent system (MAS) is a top-level orchestrator agent plus a pool of specialized subagents. The orchestrator owns the user conversation, decomposes work, calls subagents through the `subagent` tool, and synthesizes the final answer. Subagents run as isolated pi child processes with their own context windows, tools, prompts, and resource-pool settings.

This is a centralized orchestration model. It is closer to supervisor-worker and pipeline systems than to fully decentralized swarms.

## Terminology Map

| MAS literature | dot-pi artifact |
|----------------|-----------------|
| Orchestrator, supervisor, controller | `agents/<name>/SYSTEM.md` plus `agent-orchestrator` |
| Worker, specialist, role agent | A subagent config under `agents/<name>/agents/` |
| Agent capability card | `README.md` and `USAGE.md` in a subagent config |
| Blackboard or shared workspace | Workspace directory and artifact files such as `sources/` or `report.md` |
| Tool restriction | Subagent-specific pi config, tools, skills, and prompts |
| Evaluation agent | A reviewer, editor, scanner, or retro subagent |
| Resource scheduler | `resource-pool.conf` plus root `agent-orchestrator.conf` |

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
- Use `parallel` only for logically independent work. Let `agent-orchestrator` resource pools decide physical concurrency.
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

## How This Maps To dot-pi

Start with a simple orchestrator-worker design. Add pipelines when the workflow is stable, evaluator agents when quality matters, and resource pools when concurrency meets real infrastructure limits. Reach for more experimental patterns like debate or swarm coordination only after the basic artifact flow and eval loop are reliable.
