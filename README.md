# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent configs as dotfiles.

Manage multiple pi coding agent configurations without touching `~/.pi/`. Each multi-agent system (MAS) or standalone agent gets its own isolated directory with extensions, subagents, prompts, skills, and session history. A shell function sets `PI_CODING_AGENT_DIR` and you're running a fully isolated agent from any working directory.

## Quick Start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

Or install manually — see [docs/install.md](docs/install.md) for details.

### Shell integration

Commands are available directly on `PATH` via symlinks in `bin/`. Run `dotpi sync` to rebuild symlinks after adding or removing agent configs. Commands on PATH get native shell completion automatically.

## Create a Multi-Agent System

```bash
dotpi create my-research-mas
# Add or link subagents under agents/my-research-mas/agents/
# Edit agents/my-research-mas/SYSTEM.md for the orchestrator
```

## Version

```bash
dotpi --version
```

Tracked in [VERSION](VERSION); bump on releases.

## Docs

See the [documentation site](https://PlebeiusGaragicus.github.io/dot-pi/) for architecture, usage, extension API, and MAS details.
