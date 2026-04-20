# Minimal Extension

Compact footer showing the current model ID and a 10-block context-usage bar.

```
 anthropic/claude-sonnet-4-5    [###-------] 30%
```

## Files

- `index.ts` -- Footer renderer wired on `session_start`

## How It Works

- Sets the window title to `π - minimal` after a 150ms delay (lets pi finish its own title set).
- Replaces the footer via `ctx.ui.setFooter()` with a renderer that pulls `ctx.model?.id` and `ctx.getContextUsage().percent` on every render pass.
- The bar is `#` (filled) and `-` (empty) over 10 blocks.

## Hooks Registered

- `session_start`

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
