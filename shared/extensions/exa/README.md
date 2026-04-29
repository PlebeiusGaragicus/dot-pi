# Exa API Key Extension

Provides `/exa-api-key` for configuring a repo-local Exa API key. The Exa search commands themselves live in the `exa-search` skill scripts; this extension intentionally does not register a search tool.

## Files

- `index.ts` -- Registers `/exa-api-key` and reads/writes the repo-root `.exa` file.

## Configuration

API key resolution follows the same order as the skill scripts:

1. `EXA_API_KEY` environment variable
2. Repo-root `.exa` file, written as `EXA_API_KEY=<key>`

The `.exa` file is local credentials state and must stay gitignored.

## Command

Run this inside a pi agent that has the extension linked:

```text
/exa-api-key
```

The command shows the currently configured key in masked form, prompts for a new key, and saves it to `.exa`.

## Related Skill

Use the `exa-search` skill for actual Exa searches and content retrieval:

- `scripts/exa-search.js`
- `scripts/exa-contents.js`
- `scripts/exa-similar.js`
