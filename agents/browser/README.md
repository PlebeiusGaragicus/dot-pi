# browser

Standalone dot-pi browser automation agent backed by `utilities/browser-runtime`.

## Usage

```bash
browser "open https://example.com and summarize the page"
browser
```

The agent uses the `browser-control` CLI for persistent Playwright Chromium state under each project’s `.browser-control/` directory.
