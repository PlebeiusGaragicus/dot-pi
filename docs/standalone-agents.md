# Standalone Agents

Standalone agents are single-purpose pi configurations with custom extensions. Unlike team-style agents, they don't use subagent orchestration — the main pi process IS the agent, and behavior is customized entirely through extensions.

## When to Use

Use a standalone agent when you want:

- A custom tool or lifecycle hook without multi-agent delegation
- A focused, single-purpose agent (game, utility, specialized workflow)
- A playground for experimenting with the [extension API](reference/extensions.md)

Use a [team](architecture.md) when you want multiple specialized subagents that collaborate.

## Directory Layout

```
agents/<name>/
├── extensions/
│   ├── <name>/               # Your custom extension
│   │   └── index.ts
│   ├── run-finish-notify.ts  # Shared notification extension (symlinked)
│   ├── startup-branding.ts   # Shared startup branding (symlinked)
│   └── say.ts                # Shared TTS / say (symlinked by default scaffold)
├── AGENT.md                  # (optional) Requires agent-prompt.ts symlink — see below
├── SYSTEM.md                 # (optional) Replaces pi's default system prompt
├── APPEND_SYSTEM.md          # (optional) Appends to pi's default system prompt
├── pi-args                   # (optional) Default CLI flags (read by dispatch-agent)
├── skills/                   # Add skills with dotpi link-skill <name> <skill>
├── themes/                   # Per-theme symlinks from shared/themes/
├── banner.txt                # Startup branding (ASCII art + usage text)
├── bin/                      # → shared/bin/ (fd, rg)
├── models.json               # → shared/models.json
├── sessions/                 # Runtime conversation history (gitignored)
└── settings.json             # Pi settings: theme, quietStartup (gitignored)
```

The directory is a complete `PI_CODING_AGENT_DIR` root, just like a team directory. The key differences:

| | Team | Standalone Agent |
|--|------|-----------------|
| `subagent-teams` extension | Symlinked | Not present |
| `agents/` subdirectory | Subagent definitions | Not present |
| `prompts/` subdirectory | Workflow templates | Not present |
| `team-prompt.md` | Orchestrator instructions | `SYSTEM.md` / `APPEND_SYSTEM.md`, optional `AGENT.md` + `agent-prompt.ts` |
| Custom extension | Optional | Core of the agent |

## Creating a Standalone Agent

### Scaffolding

```bash
dotpi create-agent my-agent
```

This creates the directory structure with shared symlinks and a stub extension at `agents/my-agent/extensions/my-agent/index.ts`.

### Customizing the Prompt and Tools

**Preferred (pi-native): `SYSTEM.md` / `APPEND_SYSTEM.md` + `pi-args`**

Pi discovers these files from `PI_CODING_AGENT_DIR`:

- **`SYSTEM.md`** — replaces pi's entire default system prompt
- **`APPEND_SYSTEM.md`** — appends to pi's default prompt (preserves built-in tool docs and guidelines)

For tool restriction, use a **`pi-args`** file with CLI flags:

```
# pi-args — default CLI flags, one per line
--tools websearch
--no-skills
--no-context-files
```

The `dispatch-agent` script reads this file and prepends the flags to every `pi` invocation. Lines starting with `#` are comments.

Available flags include `--tools <list>` (whitelist), `--no-tools` (disable all built-in tools), `--no-skills`, `--no-prompt-templates`, `--no-context-files`, `--model <provider/id>`, etc. See `pi --help` for the full list.

Use `--no-context-files` for non-coding agents and workspace agents that should not inherit repository instructions such as `AGENTS.md` from parent directories. Omit it only when the agent is meant to work inside codebases and should read project guidance, such as the `coder` agent.

**Optional: `AGENT.md` (via manually linked `agent-prompt` extension)**

YAML frontmatter + markdown body, similar to `team-prompt.md` for team-style agents. **`dotpi create-agent` does not symlink `agent-prompt`.** To use it:

```bash
ln -sf ../../../shared/extensions/agent-prompt agents/<name>/extensions/agent-prompt
```

Then add `AGENT.md` with frontmatter (`tools`, `model`) and a body. The `agent-prompt` extension (`shared/extensions/agent-prompt/index.ts`) applies tools/model on `session_start` and appends the body via `before_agent_start`.

**Combining:** `SYSTEM.md` sets the base prompt; with `AGENT.md` + `agent-prompt`, the body can append and frontmatter can restrict tools/model.

### Writing the Extension

Edit the stub extension to add custom tools and behavior. See [Writing Extensions](reference/extensions.md) for the full API.

### Running the Agent

After running `dotpi sync`, standalone agents are available as direct commands:

```bash
dotpi sync
my-agent "hello"
```

Or set the environment variable directly:

```bash
PI_CODING_AGENT_DIR=~/.dot-pi/agents/my-agent pi "hello"
```

## Examples

### LM (Method 2 — zero code)

The simplest possible agent. Uses `SYSTEM.md` + `pi-args` with no custom extension code at all.

- `SYSTEM.md` — conversational assistant persona
- `pi-args` — `--no-tools`, `--no-skills`, `--no-prompt-templates`
- No custom extension directory, no `AGENT.md`

```bash
lm "explain the difference between TCP and UDP"
```

### Web (Method 1 — AGENT.md + custom tool)

A focused search agent using the `agent-prompt` extension and a custom `websearch` tool extension.

- `AGENT.md` — `tools: websearch` (restricts to websearch only); body describes the search agent persona
- `SYSTEM.md` — replaces pi's default prompt with a minimal search-focused instruction
- `extensions/websearch/` — Tavily Search API tool (reusable, can be symlinked into other agents)
- `extensions/agent-prompt.ts` — shared extension that loads `AGENT.md`

```bash
web "latest developments in quantum computing"
```

### Twenty Questions (extension-only)

Demonstrates a custom extension with a welcome overlay and system prompt injection — no `AGENT.md` or `SYSTEM.md`.

1. On extension load, shows a styled ANSI box telling the user to think of something
2. Injects game rules into the system prompt via `before_agent_start`
3. The agent plays 20 questions, asking yes/no questions to guess what the user is thinking of

```bash
twenty-questions
```

Source: `agents/twenty-questions/extensions/twenty-questions/index.ts`

## Customizing

### Skills

`skills/` starts empty. Add shared skills:

```bash
dotpi link-skill my-agent searxng
```

Remove a symlink to drop a skill:

```bash
rm agents/my-agent/skills/playwright
```

### Adding Agent-Specific Files

Place any files your extension needs in the agent directory. Use `getAgentDir()` to locate them:

```typescript
const agentDir = getAgentDir();
const myFile = path.join(agentDir, "my-config.json");
```

### Sharing Auth

To reuse authentication from a team:

```bash
dotpi link-auth recon my-agent
```
