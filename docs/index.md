# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

## What is this?

dot-pi is a dotfiles-style repository for managing multiple **pi coding agent** configurations. Instead of cluttering `~/.pi/` with extensions, agents, and prompts, this repo defines self-contained **team directories** and **standalone agent directories** -- each with its own extensions, skills, and session history.

The `p` command sets `PI_CODING_AGENT_DIR` to the right directory, and you get a fully isolated pi agent configuration from any working directory.

## Quick Start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install.sh)"
```

Or install manually — see [Installation & Setup](install.md) for details.

Then use a team from any project:

```bash
cd /any/project
p recon "Find all authentication code"
p blog "Write a post about this project's architecture"
```

## Teams

Teams are multi-agent configurations with orchestrated delegation (single, parallel, chain). Each team has its own set of specialized subagents, prompt templates, and an orchestrator system prompt. See the **Teams** section in the sidebar for details on each team.

## Standalone Agents

Standalone agents are single-purpose configurations with custom extensions instead of subagent orchestration. See [Standalone Agents](standalone-agents.md) for the concept and individual agent pages.

## Creating New Configurations

```bash
dotpi create my-team                        # new team
dotpi create --workspace my-research-team   # new workspace team
dotpi create-agent my-agent                 # new standalone agent
```

All configurations are invokable via `p <name>` after re-sourcing `bash_aliases`. Workspace agents (those with a `workspace.conf` file) launch in a fresh dated directory under `workspaces/` and support `--list` and `--resume`. See the [Usage Guide](usage.md) for details.
