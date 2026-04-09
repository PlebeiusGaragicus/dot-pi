---
name: bowser
description: Headless browser automation using Playwright CLI. Use when you need headless browsing, parallel browser sessions, UI testing, screenshots, web scraping, or browser automation that can run in the background. Keywords - playwright, headless, browser, test, screenshot, scrape, parallel.
allowed-tools: Bash
---

# Playwright Bowser

## Purpose

Automate browsers using `playwright-cli` — a token-efficient CLI for Playwright. Runs headless by default, supports parallel sessions via named sessions (`-s=`), and doesn't load tool schemas into context.

## Key Details

- **Headless by default** — pass `--headed` to `open` to see the browser
- **Parallel sessions** — use `-s=<name>` to run multiple independent browser instances
- **Persistent profiles** — cookies and storage state preserved between calls
- **Token-efficient** — CLI-based, no accessibility trees or tool schemas in context
- **Vision mode** (opt-in) — set `PLAYWRIGHT_MCP_CAPS=vision` to receive screenshots as image responses in context instead of just saving to disk

## Sessions

**Always use a named session.** Derive a short, descriptive kebab-case name from the user's prompt. This gives each task a persistent browser profile (cookies, localStorage, history) that accumulates across calls.

```bash
# Derive session name from prompt context:
# "test the checkout flow on mystore.com" → -s=mystore-checkout
# "scrape pricing from competitor.com"    → -s=competitor-pricing
# "UI test the login page"               → -s=login-ui-test

playwright-cli -s=mystore-checkout open https://mystore.com --persistent
playwright-cli -s=mystore-checkout snapshot
playwright-cli -s=mystore-checkout click e12
```

Managing sessions:
```bash
playwright-cli list                                     # list all sessions
playwright-cli close-all                                # close all sessions
playwright-cli -s=<name> close                          # close specific session
playwright-cli -s=<name> delete-data                    # wipe session profile
```

## Quick Reference

```
Core:       open [url], goto <url>, click <ref>, fill <ref> <text>, type <text>, snapshot, screenshot [ref], close
Navigate:   go-back, go-forward, reload
Keyboard:   press <key>, keydown <key>, keyup <key>
Mouse:      mousemove <x> <y>, mousedown, mouseup, mousewheel <dx> <dy>
Tabs:       tab-list, tab-new [url], tab-close [index], tab-select <index>
Save:       screenshot [ref], pdf, screenshot --filename=f
Storage:    state-save, state-load, cookie-*, localstorage-*, sessionstorage-*
Network:    route <pattern>, route-list, unroute, network
DevTools:   console, run-code <code>, tracing-start/stop, video-start/stop
Sessions:   -s=<name> <cmd>, list, close-all, kill-all
Config:     open --headed, open --browser=chrome, resize <w> <h>
```

## Workflow

1. Derive a session name from the user's prompt and open with `--persistent` to preserve cookies/state. Always set the viewport via env var at launch:
```bash
PLAYWRIGHT_MCP_VIEWPORT_SIZE=1440x900 playwright-cli -s=<session-name> open <url> --persistent
# or headed:
PLAYWRIGHT_MCP_VIEWPORT_SIZE=1440x900 playwright-cli -s=<session-name> open <url> --persistent --headed
# or with vision (screenshots returned as image responses in context):
PLAYWRIGHT_MCP_VIEWPORT_SIZE=1440x900 PLAYWRIGHT_MCP_CAPS=vision playwright-cli -s=<session-name> open <url> --persistent
```

2. Get element references via snapshot:
```bash
playwright-cli -s=<session-name> snapshot
```

3. Interact using refs from snapshot:
```bash
playwright-cli -s=<session-name> click <ref>
playwright-cli -s=<session-name> fill <ref> "text"
playwright-cli -s=<session-name> type "text"
playwright-cli -s=<session-name> press Enter
```

4. Scroll the page using `mousewheel` (NOT `run-code`):
```bash
playwright-cli -s=<session-name> mousewheel 0 500      # scroll down 500px
playwright-cli -s=<session-name> mousewheel 0 -500     # scroll up 500px
playwright-cli -s=<session-name> mousewheel 0 2000     # scroll down a full page
```

5. Capture results:
```bash
playwright-cli -s=<session-name> screenshot
playwright-cli -s=<session-name> screenshot --filename=output.png
```

6. **Always close the session when done.** This is not optional — close the named session after finishing your task:
```bash
playwright-cli -s=<session-name> close
```

## Gotchas

- **Always include `-s=<session-name>` on every command.** Omitting it creates an unnamed session that can't be reused or cleaned up.
- **Scrolling: use `mousewheel`, not `run-code`.** The `run-code` command runs in a Node.js context where `window` and `document` are not defined. It also rejects trailing semicolons. Use `mousewheel 0 <pixels>` instead — it's simpler and reliable.
- **Prefer snapshots over screenshots for page content.** Snapshot YAML files contain the full accessibility tree with all text and are far more token-efficient. Read screenshots when you need to assess visual layout, styling, or images that aren't captured in the accessibility tree.
- **Reuse a single session per task.** Don't open a new session for each page section. Navigate within the same session using `click`, `goto`, or `mousewheel`. Only use separate sessions for truly independent parallel tasks.
- **Snapshot before interacting.** Always take a fresh `snapshot` to get current element refs. Refs change after navigation or DOM updates.

## Configuration

If a `playwright-cli.json` exists in the working directorrm -rf /tmp/website-reviewy, use it automatically. If the user provides a path to a config file, use `--config path/to/config.json`. Otherwise, skip configuration — the env var and CLI defaults are sufficient.

```json
{
  "browser": {
    "browserName": "chromium",
    "launchOptions": { "headless": true },
    "contextOptions": { "viewport": { "width": 1440, "height": 900 } }
  },
  "outputDir": "./screenshots"
}
```

## Full Help

Run `playwright-cli --help` or `playwright-cli --help <command>` for detailed command usage.

See [docs/playwright-cli.md](docs/playwright-cli.md) for full documentation.
