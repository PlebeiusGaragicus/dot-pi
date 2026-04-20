# Run Finish Notify Extension

Sends a desktop and in-TUI notification when the agent finishes processing a user prompt.

## Files

- `index.ts` -- Cross-platform notification dispatch on `agent_end`

## Platforms

- **macOS** -- `osascript` AppleScript notification with the `Glass` sound
- **Linux** -- `notify-send` if available
- **Windows** -- PowerShell toast (only inside Windows Terminal: `WT_SESSION` set)
- **Fallback** -- terminal escape codes (Kitty `OSC 99` if `KITTY_WINDOW_ID` is set, otherwise `OSC 777` for Ghostty/iTerm2/WezTerm/urxvt)

Skipped entirely when `process.stdout.isTTY` is false.

## Behavior

- Inspects `event.messages` to detect whether tool calls ran during the turn.
- Calls `ctx.ui.notify("Pi Agent", ...)` for the in-app banner.
- Calls the platform-specific notifier with a body of either `"Run completed with tool calls"` or `"Run completed - ready for input"`.

## Hooks Registered

- `agent_end`

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/) -- referenced as a worked example
