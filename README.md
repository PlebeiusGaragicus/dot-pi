# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

Manage multiple pi coding agent configurations without touching `~/.pi/`. Each team or standalone agent gets its own isolated directory with extensions, agents, prompts, skills, and session history. A shell function sets `PI_CODING_AGENT_DIR` and you're running a fully isolated agent from any working directory.

## Quick Start

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

Or install manually — see [INSTALL.md](INSTALL.md) for details.

### Shell integration

Commands are available directly on `PATH` via symlinks in `bin/`. Run `dotpi sync` to rebuild symlinks after adding or removing teams/agents. Commands on PATH get native shell completion automatically.

## Create a Team

```bash
dotpi create my-team
# Add agents to teams/my-team/agents/
# Add prompts to teams/my-team/prompts/
```

## Version

```bash
dotpi --version
```

Tracked in [VERSION](VERSION); bump on releases.

## Docs

See the [documentation site](https://PlebeiusGaragicus.github.io/dot-pi/) for architecture, usage, extension API, and per-team details.
