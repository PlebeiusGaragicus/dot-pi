# Tavily Web Search Extension (Deprecated)

This extension is deprecated. Prefer the `tavily-search` skill, which exposes script-based Tavily search and extraction through `skills/tavily-search/scripts/`, similar to the Exa skill.

Direct Tavily REST-API access via a structured `tavily_search` tool. Avoids having agents shell out to `curl` and parse `jq` output. Also displays plan-quota usage in the footer status bar.

## Files

- `index.ts` -- Tool registration, request/response handling, footer usage widget

## Configuration

Store API keys under **`$DOT_PI_OVERLAY`** using the **`env.<service>`** convention:

- **`env.tavily`** — `TAVILY_API_KEY=...`, written by `/tavily-api-key`
- Or set `TAVILY_API_KEY` in the environment (takes precedence over the file).

Without a key, the tool registers but every call errors.

## Tool: `tavily_search`

Deliberately narrow surface - the model can only set:

- `query` (string, required)
- `max_results` (number, optional, 1-20, default 10)
- `topic` -- `"general" | "news" | "finance"`
- `time_range` -- `"day" | "week" | "month" | "year"`

The following are **hard-enforced** in every request and intentionally not exposed to the model:

- `search_depth: "basic"` -- `advanced` doubles credit cost; basic is the sane default.
- `include_raw_content: true` -- the agent always synthesizes from raw page excerpts.
- `include_answer: false` -- never trust Tavily's pre-canned summary; the agent does its own synthesis.

`include_domains` / `exclude_domains` are not exposed; if domain scoping is needed, add it back deliberately.

Responses include `results[]` with `title`/`url`/`content`/`raw_content`, and a per-request `usage.credits` count.

## Footer Usage

On `session_start`, calls `GET /usage` to bootstrap a `FooterUsageState` (`used`, `limit`, `plan`, `searchUsed`, optional `paygo`). Each search increments `searchUsed` by `usage.credits`. PAYG allocation is shown from bootstrap only and is not incremented per search (allocation is ambiguous).

The footer renderer scales the bar to ~80% of terminal width, clamped between 10 and 60 columns.

## Hooks Registered

- `session_start` -- bootstrap usage and install the footer widget

## Related Docs

- [Tavily API Reference](https://docs.tavily.com/documentation/api-reference/endpoint/search)
- [Tavily Best Practices](https://docs.tavily.com/documentation/best-practices/best-practices-search)
- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
