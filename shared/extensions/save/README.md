# Save Extension

Save the last assistant reply as a markdown file via `/save`.

## Files

- `index.ts` -- `/save` command registration and file-write logic

## Behavior

- Extracts the last assistant message from the session (skips aborted empties, concatenates `type: "text"` content parts, preserves full markdown).
- Prompts for a filename via `ctx.ui.input`. Appends `.md` if missing.
- Prompts for a destination directory via `ctx.ui.select`: home (`~/`), Downloads (`~/Downloads/`), or the current working directory.
- Writes the file with `fs.writeFileSync` and notifies success or failure.
- Gated on `ctx.hasUI` (no-op in non-interactive mode).

## Commands

- `/save` -- save the last assistant reply to a markdown file

## Hooks Registered

None.

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
