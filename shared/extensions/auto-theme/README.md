# Auto Theme Extension

Applies the first custom theme discovered in `<agentDir>/themes/` on session start. Lets dot-pi agent configs ship a default theme via symlinks into `themes/` without depending on the gitignored `settings.json`.

## Files

- `index.ts` -- Discovers and applies the first matching custom theme

## How It Works

1. On `session_start`, lists `*.json` files under `<agentDir>/themes/`.
2. Cross-references those filenames against `ctx.ui.getAllThemes()`.
3. If a match is found and is not already active, calls `ctx.ui.setTheme(name)`.

No-op when `ctx.hasUI` is false or the `themes/` folder doesn't exist.

## Hooks Registered

- `session_start`

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
