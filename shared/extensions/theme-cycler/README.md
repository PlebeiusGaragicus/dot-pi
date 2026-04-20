# Theme Cycler Extension

Keyboard shortcuts and a `/theme` command for cycling through and selecting available themes, with a flash swatch widget after each switch.

## Files

- `index.ts` -- Shortcuts, command, status line, swatch widget

## Shortcuts

- `Ctrl+X` -- cycle theme forward
- `Ctrl+Q` -- cycle theme backward

## Commands

- `/theme` -- open a select picker showing all themes (with active marker and source path)
- `/theme <name>` -- switch directly by name

## UI

- Status line shows the current theme: `🎨 <name>`
- After each switch, a 3-second swatch widget renders below the editor with success/accent/warning/dim/muted color blocks
- Any in-flight swatch is cleared on `session_shutdown`

## Hooks Registered

- `session_start` -- sets title to `π - theme-cycler` and initializes the status line
- `session_shutdown` -- clears any pending swatch timer

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
