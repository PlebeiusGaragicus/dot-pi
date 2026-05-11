# Usage Guide

This guide covers the common day-to-day command flow. For exact terminal syntax, see [Terminal Dispatch](terminal-dispatch.md).

## Prerequisites

Install with Pi and put the installed package's `core/bin` on your `PATH`:

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

Multi-agent systems use an orchestrator with the `subagent` tool:

```bash
cd ~/projects/some-api
recon - "Find all authentication-related code"
```

The orchestrator may delegate to subagents, then synthesize the result.

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

## Create A Custom MAS

```bash
dotpi create docs-mas
```

This creates `agents/docs-mas/` with shared extensions, themes, prompts, auth/model/settings links, and the orchestrator extension. Add or link subagents under `agents/docs-mas/agents/`, then run:

```bash
dotpi relink
cd ~/projects/my-api
docs-mas - "Write API reference docs for all endpoints in src/routes/"
```

## Create A Standalone Agent

```bash
dotpi create-agent my-agent
```

Edit `agents/my-agent/SYSTEM.md`, `USAGE.md`, `pi-args`, and the stub extension if needed.

## Local Defaults And Auth

Configure providers:

```bash
dotpi setup
```

Configure fallback model aliases:

```bash
dotpi model-defaults
```

These aliases are stored in `$DOT_PI_OVERLAY/model-defaults`. Agent-local `.model` overrides are stored under the overlay as well.

Auth and model provider catalogs use Pi's standard files:

```text
~/.pi/agent/auth.json
~/.pi/agent/models.json
```

## Check Your Setup

```bash
dotpi list
dotpi relink
```
