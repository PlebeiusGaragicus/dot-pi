# dot-pi

dot-pi packages multiple [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent configurations behind first-class shell commands.

## Quick Start

```bash
pi install git:https://github.com/PlebeiusGaragicus/dot-pi
```

Add the installed `core/bin` path to your shell (postinstall prints **`dotpi symlink-agents`** when needed), then run an agent from any project:

```bash
cd /any/project
ask -p "Explain this repository"
```

Use `pi update` for upgrades.

## Local development

To hack on dot-pi from a **git clone**, put **that clone’s** `core/bin` first on `PATH` after `npm install` in the clone—no `pi update` per edit—or run **`./dotpi symlink-agents --rc ~/.zshrc`** once. See the [README](https://github.com/PlebeiusGaragicus/dot-pi#local-development) **Local development** section for steps and the optional `core/tests` TypeScript check.

## How It Works

- Pi owns the package clone under `~/.pi/agent/git/...`.
- Agent commands set `PI_CODING_AGENT_DIR` to `agents/<name>/` inside that clone.
- Runtime sessions and user-owned files live under `$DOT_PI_OVERLAY`, defaulting to `~/.pi/dot-pi`.
- The package root is inert for vanilla `pi`, so registering dot-pi does not load dot-pi resources into ordinary bare `pi` sessions.

## Create Configurations

```bash
dotpi create my-research-mas
dotpi create-agent my-agent
```

All top-level agents run in-situ in the current working directory. Workspace mode and the global `resume` picker have been removed.
