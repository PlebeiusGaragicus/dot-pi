# Tavily Web Search Extension

Direct Tavily REST-API access via a structured `tavily_search` tool. Avoids having agents shell out to `curl` and parse `jq` output. Also displays plan-quota usage in the footer status bar.

## Files

- `index.ts` -- Tool registration, request/response handling, footer usage widget

## Configuration

- `TAVILY_API_KEY` -- required environment variable. Without it, the tool registers but every call errors.

## Tool: `tavily_search`

Parameters mirror the Tavily `/search` endpoint:

- `query` (string, required)
- `max_results` (number, optional)
- `search_depth` -- `"basic" | "fast" | "advanced" | "ultra-fast"`
- `topic` -- `"general" | "news" | "finance"`
- `include_answer` -- `boolean | "advanced"`
- `time_range` -- `"day" | "week" | "month" | "year"`
- (plus the rest of Tavily's documented options)

Responses include `answer`, `results[]` with `title`/`url`/`content`/`score`, and a per-request `usage.credits` count.

## Footer Usage

On `session_start`, calls `GET /usage` to bootstrap a `FooterUsageState` (`used`, `limit`, `plan`, `searchUsed`, optional `paygo`). Each search increments `searchUsed` by `usage.credits`. PAYG allocation is shown from bootstrap only and is not incremented per search (allocation is ambiguous).

The footer renderer scales the bar to ~80% of terminal width, clamped between 10 and 60 columns.

## Hooks Registered

- `session_start` -- bootstrap usage and install the footer widget

## Related Docs

- [Tavily API Reference](https://docs.tavily.com/documentation/api-reference/endpoint/search)
- [Tavily Best Practices](https://docs.tavily.com/documentation/best-practices/best-practices-search)
- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
