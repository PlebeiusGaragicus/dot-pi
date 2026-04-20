# Startup Branding Extension

Renders a custom header from `<agentDir>/banner.txt` on session start. Plays nicely with `quietStartup` -- the empty built-in header is swapped for the branded one.

## Files

- `index.ts` -- Reads `banner.txt`, sets the header via `ctx.ui.setHeader()`

## File Format

Plain text. An optional `---` separator splits the file into two zones:

```
  ___  _   _  __ _  __ _ _   _
 / _ \| | | |/ _` |/ _` | | | |
| (_) | |_| | (_| | (_| | |_| |
 \___/ \__,_|\__,_|\__, |\__, |
                   |___/ |___/
---
A focused research agent. Type your question to begin.
```

- Above `---` -- accent color, bold (intended for figlet ASCII art)
- Below `---` -- dim color (intended for usage text)
- No separator -- the entire file is rendered in accent color

Generate art with: `figlet -f small "<name>" > banner.txt`

## Hooks Registered

- `session_start` -- no-op when `ctx.hasUI` is false or `banner.txt` is missing/empty

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
