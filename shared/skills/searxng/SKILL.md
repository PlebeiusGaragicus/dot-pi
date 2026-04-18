---
name: searxng
description: "Search the web via bash+curl against http://localhost:8080. MUST use format=json and jq. No searxng tool exists."
allowed-tools: Bash
---

## Search Command

ALWAYS use this exact command (replace QUERY, encode spaces as `+`):

```bash
curl -s "http://localhost:8080/search?q=QUERY&format=json" \
  | jq '.results[:5] | .[] | {title, url, content}'
```

Do NOT use `--data-urlencode`, POST, or omit `format=json`.

## URLs Only

```bash
curl -s "http://localhost:8080/search?q=QUERY&format=json" \
  | jq -r '.results[:5] | .[].url'
```

## Response Format

Each result object contains:

| Field     | Description              |
|-----------|--------------------------|
| `title`   | Page title               |
| `url`     | Full URL                 |
| `content` | Text snippet             |
| `engine`  | Search engine source     |
| `score`   | Relevance score          |

## Optional Parameters

Append these to the query string as needed:

- `categories` -- e.g. `news`, `images`, `videos`, `science`
- `engines` -- e.g. `google`, `duckduckgo`, `wikipedia`
- `language` -- e.g. `en`, `de`, `fr`
- `pageno` -- page number for pagination (starts at 1)

Example: `curl -s "http://localhost:8080/search?q=bitcoin&format=json&categories=news"`

## Troubleshooting

If `curl` returns "connection refused", the Docker container needs to be started. If queries return errors or empty results, read `troubleshoot.md` in this skill directory.
