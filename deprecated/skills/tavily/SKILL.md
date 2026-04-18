---
name: tavily
description: "Search the web via Tavily's REST API. Prefer the tavily_search tool over bash commands when possible."
allowed-tools: Bash, tavily_search
---

## Quick Start

**Preferred approach**: Use the `tavily_search` tool directly for most searches.

```typescript
{
  "query": "your search terms",
  "max_results": 5,
  "topic": "general"
}
```

This returns structured results with titles, URLs, content snippets, and optionally an LLM-generated answer.

**Legacy bash approach**: Use curl+jq when you need more control or the extension isn't available:

```bash
curl -sS -X POST 'https://api.tavily.com/search' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -d '{"query":"QUERY","max_results":5}' \
  | jq '.results[:5] | .[] | {title, url, content}'
```

## Response Format

Each result object contains:

| Field     | Description                                    |
|-----------|------------------------------------------------|
| `title`   | Page title                                     |
| `url`     | Full URL                                       |
| `content` | Text snippet                                   |
| `score`   | Relevance score (float)                        |

When `include_answer` is set, the top-level `answer` field contains an LLM-generated summary.

## Optional Request Fields

Add these keys to the JSON body as needed:

- `search_depth` -- `"basic"` (default), `"fast"`, `"advanced"` (2 credits), `"ultra-fast"`
- `topic` -- `"general"` (default), `"news"`, `"finance"`
- `include_answer` -- `true` or `"advanced"` for an LLM-generated answer
- `time_range` -- `"day"`, `"week"`, `"month"`, `"year"`
- `include_raw_content` -- `true` for full cleaned page content
- `include_domains` / `exclude_domains` -- JSON arrays of domain strings

## URLs Only

```bash
curl -sS -X POST 'https://api.tavily.com/search' \
  -H 'Content-Type: application/json' \
  -H "Authorization: Bearer $TAVILY_API_KEY" \
  -d '{"query":"QUERY","max_results":5}' \
  | jq -r '.results[:5] | .[].url'
```

## Troubleshooting

- **401 Unauthorized** -- `TAVILY_API_KEY` is missing or invalid. Ensure it is exported in the shell that launched pi.
- **429 / 432 / 433** -- Rate or plan limit exceeded. Check usage at https://app.tavily.com or contact support@tavily.com.

Never paste the API key directly into prompts or log output; always reference `$TAVILY_API_KEY`.