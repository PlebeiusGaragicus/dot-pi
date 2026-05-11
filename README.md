# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent configs as a Pi-installable package.

## Quick Start

```bash
pi install git:https://github.com/PlebeiusGaragicus/dot-pi
```

Add the installed `core/bin` directory printed by postinstall to your `PATH`, then run any shipped agent command from a project directory:

```bash
ask -p "What does this project do?"
```

Updates use ordinary Pi package management:

```bash
pi update
```

Mutable user state lives under `$DOT_PI_OVERLAY` (default `~/.pi/dot-pi`) so `pi update` can reset and clean the package clone without touching sessions, model defaults, API-key env files, prompts, skills, extensions, themes, or shared dot-pi `settings.json`.

## Shell Integration

Commands are available through symlinks in the installed package's `core/bin/`. If you add or remove local overlay resources manually, run:

```bash
dotpi relink
```

## Create Agents

```bash
dotpi create my-research-mas
dotpi create-agent my-agent
```

Both create in-situ agents. Workspace mode has been removed; sessions are stored under `$DOT_PI_OVERLAY/<agent>/sessions/`.

## Docs

See the [documentation site](https://PlebeiusGaragicus.github.io/dot-pi/) for installation, usage, extension API, and MAS details.
