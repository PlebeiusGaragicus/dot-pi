# browser

Standalone dot-pi browser automation agent backed by `utilities/browser-runtime`.

## Usage

```bash
browser "open https://example.com and summarize the page"
browser - docs audit
browser
browser --list
browser --resume
```

Inside the agent, browser automation is driven by the `browser-control` skill via `$B`, which points at the compiled browser-runtime binary or its source fallback. The `browser` command above is the launcher for this agent.

The agent runs in workspace mode through `bootstrap.sh`. Each launch or resume writes `bootstrap.log`, exports `$B` and `BROWSER_CONTROL_STATE_DIR`, checks browser-control health, and creates `workspaces/browser/<timestamp>/` with:

- `.browser-control/` for Playwright state, daemon logs, and screenshots.
- `sessions/` for the pi session JSONL files.

Use `browser --resume` to continue the latest workspace. Bootstrap runs again on resume so it can recover daemon state after reboots.
