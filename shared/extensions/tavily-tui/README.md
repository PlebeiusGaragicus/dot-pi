# Tavily TUI Extension

Provides `/tavily-api-key` and a footer usage status for agents that use the script-backed `tavily-cli` skill. This extension intentionally does not register a Tavily search tool.

## Files

- `index.ts` -- Registers key and usage commands, reads/writes **`env.tavily`**, and manages the footer status.

## Configuration

API key resolution follows the same order as the `tavily-cli` scripts:

1. `TAVILY_API_KEY` environment variable
2. **`env.tavily`** under **`$DOT_PI_OVERLAY`**, written as `TAVILY_API_KEY=<key>`

The **`env.tavily`** file is local credentials state and must stay gitignored.

## Commands

```text
/tavily-api-key
```

`/tavily-api-key` shows the current key in masked form, prompts for a new key, saves it to **`env.tavily`**, and refreshes the footer.

## Related Skill

Use the `tavily-cli` skill for actual Tavily searches and extraction:

- `scripts/tavily-search.js`
- `scripts/tavily-extract.js`
