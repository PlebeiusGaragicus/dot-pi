# Terminal Dispatch

`dotpi sync` creates shell commands in `bin/` such as `lm`, `browser`, and `deepresearch`. Each command is a symlink to `dispatch-agent`; the symlink name selects `agents/<name>/` as `PI_CODING_AGENT_DIR`, loads that agent's `pi-args`, sources `bootstrap.sh` when present, and then invokes `pi`.

This page documents the terminal contract shared by top-level standalone agents and MAS launchers.

## Core Forms

```bash
agent
```

Starts an interactive pi session with the selected agent config.

```bash
agent - prompt words...
```

Starts an interactive pi session with `prompt words...` as the first human message. The lone `-` is dot-pi's prompt separator; it is preferred over raw positional `agent "prompt"` because it leaves room for dot-pi options such as `-n`.

```bash
agent -p prompt words...
agent --print prompt words...
```

Runs non-interactively. The launcher calls pi in JSON mode with `-p`, filters the event stream, prints the final assistant reply to stdout, and exits.

```bash
agent -p -v prompt words...
agent --print --verbose prompt words...
```

Also runs non-interactively, but prints progress markers such as tool starts and `[agent done]` to stderr. The final assistant reply still goes to stdout.

## stdin

Piped stdin is treated as prompt text only when no prompt was supplied:

```bash
echo "summarize this directory" | ask -p
```

Use `-p` for piped input. A pipe is inherently non-interactive: once the launcher consumes stdin as the initial prompt, there is no terminal input left for pi's TUI. For interactive sessions, use the separator form:

```bash
ask - summarize this directory
```

## stdout And stderr

Print mode is designed for shell scripts:

- stdout: final assistant reply
- stderr: progress, workspace paths, errors, and verbose markers

Examples:

```bash
answer="$(lm -p "say hi")"
lm -p "write a summary" > summary.md
lm -p -v "debug this" > answer.md 2> progress.log
```

Without `-v`, `_json_filter` suppresses normal progress markers. Tool errors may still cause pi or the launcher to return non-zero.

## Workspace Agents

Agents with `WORKSPACE_AGENT=1` in `bootstrap.sh` run inside dated workspaces:

```bash
browser
browser - open https://example.org and summarize it
browser -p open https://example.org and summarize it
```

Name a workspace with `-n` / `--name`:

```bash
browser -n docs-audit - open https://example.org
browser -p -n docs-audit open https://example.org
```

List and resume workspaces:

```bash
browser ls
browser resume
browser resume 2026-04-29-120000--docs-audit
browser resume 2026-04-29-120000--docs-audit - continue from the last page
browser resume 2026-04-29-120000--docs-audit -p summarize the current state
```

`resume` with no argument opens an interactive picker. With an argument, it requires an exact workspace directory basename or path. `resume` changes into the existing workspace and invokes pi with `--continue`. If the workspace contains `sessions/`, that directory is passed as `--session-dir` so orchestration traces stay with the workspace.

## Bootstrap Output

If an agent has `bootstrap.sh`, it is sourced before pi starts. The script can export environment variables and prepare directories.

Bootstrap output is written to `bootstrap.log`; the file is replaced on each launch rather than appended. For workspace agents the log is under the workspace. For in-situ agents the default is `agents/<name>/sessions/bootstrap.log`.

Bootstrap output is replayed to stdout only for fully interactive startup (`agent` with no prompt and no `-p`). Prompted and print-mode runs keep stdout clean for the assistant reply.

## Help

```bash
agent help
agent usage
agent -h
agent --help
```

These print the agent root's `USAGE.md`. If it is missing, the launcher reports that the agent has no `USAGE.md`; `README.md` remains for human and agent-facing prose.
