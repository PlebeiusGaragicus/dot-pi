# Subagent Teams Extension

Team-aware subagent orchestration for pi. Registers a `subagent` tool that spawns isolated pi child processes with single, parallel, and chain execution modes.

## Files

- `index.ts` -- Extension entry point: tool registration, process spawning, TUI rendering
- `agents.ts` -- Agent discovery and team-based filtering logic

## Documentation

See the [dot-pi docs](https://PlebeiusGaragicus.github.io/dot-pi/):

- [Subagent Teams Reference](https://PlebeiusGaragicus.github.io/dot-pi/reference/subagent-teams/) -- agent definition format, tool modes, team-prompt.md
- [Architecture](https://PlebeiusGaragicus.github.io/dot-pi/architecture/) -- how extensions are loaded and wired
- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/) -- extension API, hooks, tools, TUI
