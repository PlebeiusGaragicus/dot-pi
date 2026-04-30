# browser

Standalone dot-pi browser automation agent backed by `utilities/browser-runtime`.

## Bootstrap and `$B`

The launcher sources [`bootstrap.sh`](bootstrap.sh) before pi starts. That script:

- Sets **`WORKSPACE_DIR`** to a dated folder under `workspaces/browser/`.
- Exports **`B`** (compiled `browser-control` binary, or `bun run …/cli.ts` fallback).
- Exports **`BROWSER_CONTROL_STATE_DIR`** to `<workspace>/.browser-control/`.
- Runs **`$B status`** and appends to **`bootstrap.log`**.

The agent process inherits **`$B`** and **`BROWSER_CONTROL_STATE_DIR`**. In bash tool calls, run **`$B goto …`**, **`$B snapshot -i`**, etc., without repeating `export B=…` unless **`$B`** is missing or broken. See [`SYSTEM.md`](SYSTEM.md) and [`shared/skills/browser-control/SKILL.md`](../../shared/skills/browser-control/SKILL.md) for the full contract.

## Usage

Run `browser help` (or `browser usage`, `-h`, `--help`) for the full launcher synopsis. Typical flows: `browser` for an interactive workspace, `browser - …` to send an initial prompt and stay interactive, `browser ls` / `browser resume` to reuse workspaces, and `browser -p …` for non-interactive final-text output.

Each workspace includes:

- **`.browser-control/`** — Playwright state, daemon logs, screenshots.
- **`sessions/`** — pi session JSONL when the launcher passes `--session-dir`.
- **`bootstrap.log`** — bootstrap output and **`$B status`**.

`browser resume` re-runs bootstrap so **`$B`** and the state dir stay correct after reboots or new shells.
