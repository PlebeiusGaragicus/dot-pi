---
name: browser-control
description: Use for web browsing, UI interaction, screenshots, scraping, and repeatable browser skills. Read skill before using browser.
disable-model-invocation: false
---

# Browser Control

**`browser-control` is the product name for this CLI, not a command on `PATH`.** Invoke it only as **`$B <subcommand> …`**.

Use **`$B`** to drive a persistent Playwright Chromium daemon. The first command starts the daemon; later commands reuse the same browser state through `.browser-control/browse.json`. By default this is project-local; workspace agents set **`BROWSER_CONTROL_STATE_DIR`** so state, screenshots, and logs stay inside the current workspace. 

## Setup

**dot-pi `browser` workspace:** `agents/browser/bootstrap.sh` runs before the agent. It exports **`B`** and **`BROWSER_CONTROL_STATE_DIR`** and runs **`$B status`**. Use **`$B …`** directly in bash; do not re-export the path on every command unless **`$B`** is unset or fails.

**Any other context** (no bootstrap, or **`$B`** empty): set **`B`** once, then use **`$B …`**:

```bash
B="$HOME/.dot-pi/utilities/browser-runtime/dist/browser-control"
[ -x "$B" ] || B="bun run $HOME/.dot-pi/utilities/browser-runtime/src/cli.ts"
export B
```

If **`$B`** is already set (e.g. from bootstrap), keep it.

## Core Workflow

```bash
$B goto https://example.com
$B snapshot -i
$B click @e1
$B fill @e2 "search text"
$B press Enter
$B text
$B screenshot
```

Run **`snapshot -i`** before clicking or filling. Re-run it after navigation, popovers, form submissions, or any UI change because refs can go stale.

## Choosing Reading Commands

Use **`snapshot -i`** when you need clickable/fillable **`@e`** refs or need to inspect page structure. For extraction tasks such as headlines, page summaries, or lists, prefer **`links`**, **`text`**, or **`html <selector>`** when reasonable. If **`snapshot -i`** already contains the headlines or list you need, answer from it before chaining more tools. Use **`skill run <name>`** when a packaged browser skill clearly matches the task.

## Commands

```text
Navigation:  goto <url>, url
Reading:     text [css], html [css], links, snapshot [-i]
Actions:     click <@e|css>, fill <@e|css> <text>, press <key>, scroll [@e|css]
Visual:      screenshot [path]
Tabs:        tabs, newtab [url], closetab [id]
Skills:      skill list, skill show <name>, skill run <name>, skill test <name>
Lifecycle:   status, stop, restart
```

## Browser Skills

Browser skills are deterministic scripts discovered from:

1. `<project>/.browser-control/browser-skills/`
2. `~/.dot-pi/browser-skills/`
3. `~/.dot-pi/utilities/browser-runtime/browser-skills/`

Use a skill when it clearly matches the task:

```bash
$B skill list
$B skill show hackernews-frontpage
$B skill run hackernews-frontpage
```

## Safety

Ask before mutating user accounts or external systems: submitting forms, posting, purchasing, deleting, or changing settings. Reading public pages, screenshots, and local extraction are fine.
