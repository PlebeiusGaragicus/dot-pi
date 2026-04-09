## Strategy for Using `pi-recipes` as an Agentic Software Development System

### The Architecture at a Glance

Pi-recipes gives you a layered orchestration system with four main primitives:

1. **Agent Personas** (`.pi/agents/*.md`) -- specialized agents with constrained tool sets and system prompts
2. **Teams** (`.pi/agents/teams.yaml`) -- named groups of agents activated together
3. **Chains** (`.pi/agents/agent-chain.yaml`) -- sequential pipelines where each agent's output feeds the next
4. **Skills** (`.pi/skills/`) -- reusable tool-backed capabilities any agent can invoke

These are coordinated through orchestration extensions that act as control planes.

---

### The Three Orchestration Modes

#### 1. Agent Team (Dispatcher Pattern)

```bash
fu ext-agent-team
# or: pi -e extensions/orchestration/agent-team.ts
```

**How it works:** The primary Pi agent becomes a **pure dispatcher** -- it has *no codebase tools at all*. It can only delegate via `dispatch_agent`. Each specialist runs in its own Pi subprocess with its own session memory.

**When to use:** Open-ended development tasks where the right workflow emerges from the problem. The dispatcher decides which agents to call and in what order.

**Your teams are pre-configured as:**

| Team | Members | Best For |
|------|---------|----------|
| `full` | scout, planner, builder, reviewer, documenter, red-team | Complete feature development |
| `plan-build` | planner, builder, reviewer | Focused implementation |
| `info` | scout, documenter, reviewer | Research and documentation |
| `frontend` | planner, builder, bowser | UI/frontend work with browser testing |

**Best practice:** Start with `plan-build` for most development tasks. Escalate to `full` when you need security review or documentation as part of the deliverable.

#### 2. Agent Chain (Pipeline Pattern)

```bash
fu ext-agent-chain
# or: pi -e extensions/orchestration/agent-chain.ts
```

**How it works:** Predefined sequential pipelines. The user's prompt flows into step 1, each step's output becomes `$INPUT` for the next step. The orchestrator keeps all its own tools *plus* the `run_chain` tool, so it can also do quick direct work.

**Your pre-configured chains:**

| Chain | Flow | Best For |
|-------|------|----------|
| `plan-build-review` | planner -> builder -> reviewer | Standard feature work |
| `full-review` | scout -> planner -> builder -> reviewer | Unfamiliar codebases |
| `plan-review-plan` | planner -> plan-reviewer -> planner | Iterative design refinement |
| `scout-flow` | scout -> scout -> scout | Deep exploration from 3 angles |

**Best practice:** Use `plan-build-review` as your default development chain. Use `full-review` when working in unfamiliar parts of the codebase where the scout's recon is valuable upfront.

#### 3. Subagent Widget (Ad-Hoc Delegation)

```bash
fu ext-subagent-widget
# or: pi -e extensions/orchestration/subagent-widget.ts
```

**How it works:** The main agent spawns background subagents on the fly via `/sub <task>` commands or the `subagent_create` tool. Each subagent gets a persistent session, so you can continue its conversation with `/subcont <id> <prompt>`. Live progress widgets show status in the TUI.

**When to use:** When you need parallel work on independent tasks, or quick fire-and-forget investigations that shouldn't block the main conversation.

---

### Guiding Principles for Software Development

#### Principle 1: Right-Size Your Agent Surface

Each agent persona has a deliberately constrained tool set:

- **scout** -- `read,grep,find,ls` (read-only: safe for exploration)
- **planner** -- `read,grep,find,ls` (read-only: plans, doesn't execute)
- **builder** -- `read,write,edit,bash,grep,find,ls` (full write access)
- **reviewer** -- `read,bash,grep,find,ls` (can run tests but can't write production code)
- **red-team** -- `read,bash,grep,find,ls` (can probe but can't modify)

This is a least-privilege model. Only the builder can write files. Only agents that need bash get bash. This prevents accidental mutations during research or review phases.

**Best practice:** Never give an exploration or review agent write access. If a reviewer finds an issue, the fix should flow back through the builder.

#### Principle 2: Plan Before You Build

The `plan-mode` extension (`extensions/plan-mode/`) enforces a read-only exploration phase before implementation. Use it as a discipline mechanism:

```bash
fu ext-plan-mode
```

Toggle with `/plan` or Ctrl+Alt+P. In plan mode, the agent can only read, grep, and explore. It extracts numbered plan steps, then you switch to execution mode where it tracks progress against those steps.

**Best practice for complex features:**
1. Start in plan mode -- let the agent explore the codebase and produce a structured plan
2. Review the plan yourself
3. Switch to execution mode and let the chain/team implement it
4. The `plan-review-plan` chain automates this: planner produces a plan, plan-reviewer challenges it, planner refines

#### Principle 3: Layer Your Safety Stack

Pi-recipes provides multiple safety extensions. Stack them defensively:

```bash
# The "damage control" recipe stacks these together:
fu ext-damage-control
```

Key safety extensions to consider:

- **damage-control** -- YAML-rule-based blocking of dangerous bash patterns
- **permission-gate** -- confirms before `rm -rf`, `sudo`, `chmod 777`
- **protected-paths** -- blocks writes to `.env`, `.git/`, `node_modules/`
- **dirty-repo-guard** -- prevents agent changes when you have uncommitted work
- **git-checkpoint** -- stashes at each turn, can restore on fork

**Best practice:** Always run `git-checkpoint` when using builder agents. If something goes wrong, you can restore from any turn.

#### Principle 4: Use Skills as Shared Capabilities

Skills are agent-agnostic tool packages. Any agent in any orchestration mode can use them. Your key skills:

| Skill | Purpose in Development |
|-------|----------------------|
| `commit` | Standardized conventional commits |
| `github` | PR creation, CI status, issue management |
| `web-browser` | Browser automation for testing UIs |
| `mermaid` | Architecture diagrams and flowcharts |
| `sentry` | Error tracking and debugging |
| `tmux` | Remote session control for long-running tasks |
| `summarize` | Convert URLs/files to markdown for context |

**Best practice:** Define skills at the project level (`.pi/skills/`) for project-specific tooling, and at the global level (`~/.pi/agent/skills/`) for capabilities you want everywhere.

#### Principle 5: Compose Extensions, Don't Monolith

Pi's extension model is composable. Stack what you need:

```bash
# Combine orchestration + safety + workflow
pi -e extensions/orchestration/agent-chain.ts \
   -e extensions/safety/damage-control.ts \
   -e extensions/git/git-checkpoint.ts \
   -e extensions/workflow/todo.ts \
   -e extensions/ui/minimal.ts
```

Create justfile recipes for your common combos. The existing recipes show the pattern -- each is a curated set of extensions for a specific workflow.

---

### Recommended Development Workflows

#### Workflow A: Feature Development (Recommended Default)

```bash
fu ext-agent-chain   # uses plan-build-review chain
```

1. Describe the feature to the orchestrator
2. The chain automatically flows: **planner** (designs the approach) -> **builder** (implements it) -> **reviewer** (checks quality)
3. The orchestrator synthesizes the reviewer's feedback and reports back
4. If issues found, run the chain again with targeted fixes

#### Workflow B: Codebase Exploration + Major Refactor

```bash
fu ext-agent-team   # select 'full' team
```

1. Ask the dispatcher to have the **scout** explore the relevant area
2. Based on scout's report, ask dispatcher to send **planner** a detailed task
3. **Builder** implements the plan
4. **Reviewer** checks the result
5. **Red-team** probes for security/edge-case issues
6. **Documenter** updates relevant docs

The dispatcher coordinates all of this, remembering context across dispatches since each agent maintains session state.

#### Workflow C: Parallel Investigation

```bash
fu ext-subagent-widget
```

1. `/sub investigate the auth module for performance bottlenecks`
2. `/sub analyze the database query patterns in the API layer`
3. `/sub review error handling in the payment service`
4. All three run in parallel with live progress widgets
5. Results stream back as they complete
6. Use `/subcont 1 now fix the top 3 bottlenecks you found` to act on findings

#### Workflow D: Building Pi Extensions (Meta-Development)

```bash
fu ext-pi-pi
```

The **pi-pi** meta-agent has 8 domain experts (ext-expert, theme-expert, skill-expert, config-expert, tui-expert, prompt-expert, agent-expert, keybinding-expert) that research Pi's own APIs in parallel. Use this when building new extensions, skills, or agent personas for Pi itself.

---

### Creating Your Own Agent Personas

Agent definitions are simple markdown files with YAML frontmatter:

```markdown
---
name: my-specialist
description: Does a specific thing well
tools: read,write,edit,bash,grep,find,ls
---

You are a specialist in [domain]. Your approach:
1. First, understand the existing code structure
2. Make minimal, focused changes
3. Always verify your changes work

[Detailed system prompt with domain knowledge, constraints, preferences...]
```

Place these in `.pi/agents/` and add them to `teams.yaml` to make them available in team/chain workflows.

**Best practice for writing agent personas:**
- Be specific about methodology, not just role
- Include negative instructions (what NOT to do)
- Specify output format expectations
- Reference project conventions the agent should follow

---

### Creating Custom Chains

Add to `.pi/agents/agent-chain.yaml`:

```yaml
my-custom-chain:
  description: "Custom workflow for my project"
  steps:
    - agent: scout
      prompt: "Explore the codebase for: $INPUT"
    - agent: planner
      prompt: "Based on this exploration:\n$INPUT\n\nCreate a plan for: $ORIGINAL"
    - agent: builder
      prompt: "Implement this plan:\n$INPUT"
```

`$INPUT` is the previous step's output. `$ORIGINAL` is always the user's original prompt.

---

### Creating Custom Teams

Add to `.pi/agents/teams.yaml`:

```yaml
my-team:
  - scout
  - planner
  - builder
  - my-specialist
```

---

### Key Operational Tips

1. **Context window management** -- Each subagent gets its own context window. The grid/card widgets show context usage percentage. If an agent is at high context, its responses degrade. Start fresh sessions for new tasks.

2. **Model selection matters** -- The orchestrator inherits the model you launch Pi with. Subagents use the same model. For cost-effective development, use a fast model (Gemini Flash, Haiku) for scouts and a capable model (Sonnet, Opus) for builders and reviewers.

3. **Session persistence** -- Agent team and chain agents maintain sessions within a Pi session. When you start a new session (`/new`), all agent sessions are wiped. This is intentional -- clean slate for each task.

4. **The `fu` command** -- Set `PI_RECIPES` in your shell and use `fu` from any project directory. Pi runs in your current working directory, so project-local `.pi/` configs always apply.

5. **Inter-session control** -- The `control.ts` extension enables Unix socket-based communication between Pi sessions. This is advanced but powerful for building workflows where one session steers another.

6. **The SDK** -- For fully programmatic control, use the TypeScript SDK (`examples/sdk/`). `createAgentSession()` gives you event-stream access to a Pi session, useful for building custom orchestration beyond what the extensions provide.