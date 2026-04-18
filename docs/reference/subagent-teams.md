# Subagent Teams Extension

The `subagent-teams` extension is a team-aware fork of the upstream pi `subagent` example. It registers a `subagent` tool that spawns isolated pi child processes, each with their own context window.

Source: `shared/extensions/subagent-teams/`

## Agent Definition Format

Agents are markdown files with YAML frontmatter stored in `<agentDir>/agents/`:

```markdown
---
name: scout
description: Fast codebase recon
team: recon
tools: read, grep, find, ls, bash
skills: skills/searxng
no-skills: true
---

System prompt goes here. This becomes the --append-system-prompt
for the spawned pi child process.
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | No | Agent name (defaults to filename-derived name) |
| `description` | **Yes** | Short description (shown to the LLM for agent selection) |
| `team` | No | Team name (overrides filename convention) |
| `tools` | No | Comma-separated tool whitelist (omit for all defaults) |
| `skills` | No | Comma-separated skill paths (relative to team dir or absolute) |
| `no-skills` | No | If `true`, disables skill auto-discovery for this agent |
| `model` | No | Model override for this agent |

### Per-Agent Skills

By default, each subagent inherits all skills from the team's `skills/` directory. The `skills` and `no-skills` fields give per-agent control:

| `no-skills` | `skills` | Result |
|-------------|----------|--------|
| absent | absent | All team skills auto-discovered (default) |
| absent | set | Team skills + additional explicit skills |
| `true` | absent | No skills |
| `true` | set | Only the listed skills |

Skill paths are resolved relative to the team directory (`PI_CODING_AGENT_DIR`). For example, `skills: skills/searxng` resolves to `teams/<team>/skills/searxng`.

Shared skills live in `shared/skills/`. Add the ones you need with `./setup.sh link-skill <team> <skill>` (or `ln -sf`); each appears under `teams/<team>/skills/<name>` (e.g. `teams/blog/skills/searxng -> ../../../shared/skills/searxng`). Remove a symlink to exclude a skill. To restrict at the subagent level, use `no-skills: true` with an explicit `skills:` list.

## Team Naming Convention

The first `-` in the filename separates team from agent name:

| Filename | Team | Agent Name |
|----------|------|------------|
| `recon-scout.md` | recon | scout |
| `impl-worker.md` | impl | worker |
| `blog-editor.md` | blog | editor |
| `scout.md` | *(none)* | scout |

A `team` field in frontmatter overrides the filename-derived team.

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

Up to 8 tasks, 4 concurrent.

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

## Team Prompt (`team-prompt.md`)

If `<agentDir>/team-prompt.md` exists, the extension parses its YAML frontmatter and body at startup. The frontmatter configures the orchestrator; the body is appended to the orchestrator's system prompt.

All configuration is gated on `PI_IS_SUBAGENT` -- subagent child processes have `PI_IS_SUBAGENT=1` set in their environment by the extension, so they do not receive team-level configuration. This works correctly for both interactive sessions and non-interactive runs (eval scripts, piped output).

Startup branding is handled separately by `banner.txt` + the `startup-branding.ts` extension (not by frontmatter).

### Frontmatter Fields

```yaml
---
tools: read, find, ls, grep
model: plebchat/qwen/qwen3-coder-next
---
```

| Field | Effect |
|-------|--------|
| `tools` | Comma-separated tool whitelist for the orchestrator. The `subagent` tool is always included automatically. Omit to keep all default tools. |
| `model` | `provider/modelId` format. Sets the orchestrator's model on session start. Omit to use the default model. |

### Body

The markdown body (below the frontmatter) is appended to the orchestrator's system prompt via a `before_agent_start` hook. Use it to give the parent pi process team-specific context: available agents, workflows, and behavioral constraints.

## Agent Discovery

Agents are discovered fresh on each tool invocation from two locations:

1. **User-level**: `<PI_CODING_AGENT_DIR>/agents/`
2. **Project-level**: `.pi/agents/` (relative to cwd, walking up)

The `agentScope` parameter controls which are loaded (`"user"`, `"project"`, or `"both"`). Project agents override user agents with the same name when scope is `"both"`.
