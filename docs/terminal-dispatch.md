# Terminal Dispatch

Agent commands in `core/bin/` are symlinks to `dispatch-agent`. The symlink name selects `agents/<name>/` as `PI_CODING_AGENT_DIR`, loads that agent's `pi-args`, sets `DOT_PI_OVERLAY` when missing, adds an overlay-backed `--session-dir`, and invokes `pi`.

`core/bin/todo` is different unless an agent named `todo` exists: it points at the JSONL todo CLI.

## Core Forms

```bash
agent
```

Starts an interactive pi session in the current working directory.

```bash
agent - prompt words...
```

Starts an interactive session with `prompt words...` as the first user message. The lone `-` is dot-pi's prompt separator.

```bash
agent -p prompt words...
agent --print prompt words...
```

Runs non-interactively. The launcher calls pi in JSON mode with `-p`, filters the event stream, prints the final assistant reply to stdout, and exits.

```bash
agent -p -v prompt words...
agent --print --verbose prompt words...
```

Also prints progress markers to stderr.

## stdin

Piped stdin is treated as prompt text only when no prompt was supplied:

```bash
echo "summarize this directory" | ask -p
```

## Sessions

Dispatch always passes `--session-dir` outside the package clone:

```text
$DOT_PI_OVERLAY/<agent>/sessions/<current-working-directory-key>/
```

`agent ls` lists sessions for the current working directory.

Workspace mode, `-n/--name`, agent `resume`, and the global `resume` picker have been removed.

## Bootstrap Output

If an agent has `bootstrap.sh`, it is sourced before pi starts as an in-situ launch hook. The launcher provides:

- `DOT_PI_DIR`
- `DOT_PI_OVERLAY`
- `AGENT_NAME`
- `AGENT_DIR`
- `DOTPI_BOOTSTRAP_PHASE`
- `BOOTSTRAP_LOG`

Bootstrap output is captured in the current overlay session directory as `bootstrap.log`. Output is replayed only for fully interactive startup.

## Help

```bash
agent help
agent usage
agent -h
agent --help
```

These print the agent root's `USAGE.md`.
