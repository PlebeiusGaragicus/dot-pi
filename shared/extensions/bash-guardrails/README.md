# Bash Guardrails Extension

Blocks unsafe `bash` commands and `write` operations at the tool-call level. Steers agents toward pre-installed CLI tools instead of installing packages or executing arbitrary scripts at runtime.

## Files

- `index.ts` -- Blocked-pattern definitions and `tool_call` hook

## Blocked Bash Patterns

- Package installs: `npm install`, `npx`, `yarn add`, `pnpm install`, `pip install`, `brew install`, `apt install`
- Script execution: `node *.js|*.ts|*.mjs`, `bun run *.js|*.ts`, `python *.py`
- Pipe-to-shell: `curl ... | sh`, `wget ... | sh`

## Blocked Write Extensions

`.mjs`, `.cjs`, `.js`, `.ts`, `.py`, `.sh`, `.bash`, `.rb`, `.pl`

Blocks affect the `bash` tool's `command` arg and the `write` tool's `file_path` / `path` arg.

## Hooks Registered

- `tool_call` -- returns `{ block: true, reason }` when a pattern matches

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
