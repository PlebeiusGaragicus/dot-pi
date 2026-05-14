# Usage Guide

This guide covers the common day-to-day command flow. For exact terminal syntax, see [Terminal Dispatch](terminal-dispatch.md).

## Prerequisites

Install with Pi, then ensure agent commands are on your `PATH` (postinstall prints **`dotpi symlink-agents`** when needed, or run it manually). See [Installation](install.md#path-for-agent-commands).

```bash
pi install git:https://github.com/PlebeiusGaragicus/dot-pi
```

Mutable state lives under `$DOT_PI_OVERLAY`, defaulting to `~/.pi/dot-pi`.

## Ask About A Codebase

```bash
cd ~/projects/some-api
ask -p "What does this project do?"
```

For an interactive session:

```bash
ask - "Map the authentication flow"
```

## Use A MAS

Multi-agent systems use an orchestrator with the **`subagent`** tool ( **`top-level-agent-orchestrator`** ), delegating to the shipped capability agents `ask`, `scout`, `writer`, `coder`, and `web`:

```bash
cd ~/projects/some-api
mas - "Find all authentication-related code and summarize findings"
```

The orchestrator delegates bounded tasks to those workers, then synthesizes the result.

## Print Mode

Print mode is useful for scripts:

```bash
answer="$(ask -p "summarize this directory")"
ask -p -v "debug this" > answer.md 2> progress.log
```

## Sessions

Sessions are stored outside the package clone:

```text
$DOT_PI_OVERLAY/<agent>/sessions/<current-working-directory-key>/
```

List sessions for the current directory:

```bash
ask ls
```

Workspace mode and `resume` have been removed. To continue an old conversation, use Pi's normal session mechanics within the overlay-backed session directory.

## Create a custom MAS

Follow **[Creating a new agent](reference/creating-a-new-agent.md)** (MAS orchestrator checklist) to add **`agents/docs-mas/`** (or any name) with **`top-level-agent-orchestrator`**, shared links, and starter **`SYSTEM.md`** / **`USAGE.md`**. Edit **`SYSTEM.md`**, add workflow templates under **`prompts/`**, link skills as needed, then run:

```bash
dotpi relink
cd ~/projects/my-api
docs-mas - "Write API reference docs for all endpoints in src/routes/"
```

## Create a standalone agent

Use the same reference doc (standalone checklist) under **`agents/my-agent/`**, then **`dotpi relink`**. Edit **`SYSTEM.md`**, **`USAGE.md`**, **`pi-args`**, and the stub extension as needed.

## Local Defaults And Auth

Configure providers:

```bash
dotpi setup
```

Auth and model provider catalogs use Pi's standard files:

```text
~/.pi/agent/auth.json
~/.pi/agent/models.json
```

dot-pi links those through `$DOT_PI_OVERLAY/auth.json` and `$DOT_PI_OVERLAY/models.json`, then into each agent root.

## Check Your Setup

```bash
dotpi list
dotpi relink
```
