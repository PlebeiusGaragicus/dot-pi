---
name: browser-control
description: Persistent Playwright Chromium control through dot-pi's browser-control CLI. Use for headless browsing, UI interaction, screenshots, scraping, and repeatable browser skills.
allowed-tools: Bash
---

# Browser Control

Use `browser-control` to drive a persistent Playwright Chromium daemon. The first command starts the daemon; later commands reuse the same browser state through the project-local `.browser-control/browse.json` file.

## Setup

Set `$B` once before browser work. Prefer the compiled binary and fall back to source:

```bash
B="$HOME/.dot-pi/utilities/browser-runtime/dist/browser-control"
[ -x "$B" ] || B="bun run $HOME/.dot-pi/utilities/browser-runtime/src/cli.ts"
```

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

Run `snapshot -i` before clicking or filling. Re-run it after navigation, popovers, form submissions, or any UI change because refs can go stale.

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
