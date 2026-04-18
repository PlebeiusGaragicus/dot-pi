# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

## What is this?

dot-pi is a dotfiles-style repository for managing multiple **pi coding agent** configurations. Instead of cluttering `~/.pi/` with extensions, agents, and prompts, this repo defines self-contained **team directories** and **standalone agent directories** -- each with its own extensions, skills, and session history.

The `p` command sets `PI_CODING_AGENT_DIR` to the right directory, and you get a fully isolated pi agent configuration from any working directory.

## Quick Start

```bash
# Clone the repo
git clone git@github.com:PlebeiusGaragicus/dot-pi.git ~/dot-pi

# Source bash_aliases (defines `p`)
echo 'source ~/dot-pi/bash_aliases' >> ~/.zshrc
source ~/dot-pi/bash_aliases

# Set up API keys
cp ~/dot-pi/example.env ~/dot-pi/.env
# Edit .env with your API keys

# Use a team
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
./setup.sh create my-team                        # new team
./setup.sh create --workspace my-research-team   # new workspace team
./setup.sh create-agent my-agent                 # new standalone agent
```

All configurations are invokable via `p <name>` after re-sourcing `bash_aliases`. Workspace agents (those with a `workspace.conf` file) launch in a fresh dated directory under `workspaces/` and support `--list` and `--resume`. See the [Usage Guide](usage.md) for details.
