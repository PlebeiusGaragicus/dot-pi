# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent configs as dotfiles.

## What is this?

dot-pi is a dotfiles-style repository for managing multiple **pi coding agent** configurations. Instead of cluttering `~/.pi/` with extensions, agents, and prompts, this repo defines self-contained **multi-agent systems (MAS)** and **standalone agent directories** -- each with its own extensions, skills, and session history.

Each command (e.g. `recon`, `blog`, `lm`) sets `PI_CODING_AGENT_DIR` to the right directory, and you get a fully isolated pi agent configuration from any working directory.

## Quick Start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

Or install manually — see [Installation & Setup](install.md) for details.

Then use a MAS from any project:

```bash
cd /any/project
recon "Find all authentication code"
blog "Write a post about this project's architecture"
```

## Multi-Agent Systems

Multi-agent systems are orchestrated configurations with a top-level agent that delegates through the `subagent` tool. Each MAS has specialized subagents, prompt templates, and an orchestrator system prompt. See the **Multi-Agent Systems** section in the sidebar for bundled examples.

## Standalone Agents

Standalone agents are single-purpose configurations with custom extensions instead of subagent orchestration. See [Standalone Agents](standalone-agents.md) for the concept and individual agent pages.

## Creating New Configurations

```bash
dotpi create my-research-mas                # new MAS
dotpi create --workspace deepresearch       # new workspace MAS
dotpi create-agent my-agent                 # new standalone agent
```

All configurations are invokable as direct commands after running `dotpi sync` to rebuild bin/ symlinks. Workspace agents (those with a `workspace.env` file) launch in a fresh dated directory under `workspaces/`, support named launches such as `deepresearch - project name`, and can be reopened with `--list`, `--resume`, or the global `resume` picker. See the [Usage Guide](usage.md) for details.
