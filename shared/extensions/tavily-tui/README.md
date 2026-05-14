# Tavily TUI Extension

Provides a footer usage status for agents that use the script-backed `tavily-search` skill. Configure keys with **`dotpi keys`** or **`/api-keys`** in pi. This extension intentionally does not register a Tavily search tool.

## Files

- `index.ts` -- Reads **`env.tavily`** and manages the footer status.

## Configuration

API key resolution follows the same order as the `tavily-search` skill scripts:

1. `TAVILY_API_KEY` environment variable
2. **`env.tavily`** under **`$DOT_PI_OVERLAY`**, written as `TAVILY_API_KEY=<key>` (via **`dotpi keys`** or **`/api-keys`**)

The **`env.tavily`** file is local credentials state and must stay gitignored.

## Related skill

Use the **`tavily-search`** skill for Tavily searches and extraction:

- `scripts/tavily-search.js`
- `scripts/tavily-extract.js`
