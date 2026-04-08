---
name: searxng
description: "Read this skill file to learn the curl commands for searching the web. Use the bash tool to run curl against http://localhost:8080/search — there is no searxng tool, only bash+curl."
---

# SearXNG Web Search

Search the internet using the `bash` tool to run `curl` against a local SearXNG instance at `http://localhost:8080`.

## How to Search

Use the `bash` tool to run this command (replace YOUR_QUERY with a URL-encoded search query):

```bash
curl -s "http://localhost:8080/search?q=YOUR_QUERY&format=json" \
  | jq '.results[:5] | .[] | {title, url, content}'
```

To get just URLs:

```bash
curl -s "http://localhost:8080/search?q=YOUR_QUERY&format=json" \
  | jq -r '.results[:5] | .[].url'
```

Spaces in the query should be encoded as `+` (e.g. `iran+trump+war`).

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

- `categories` — e.g. `news`, `images`, `videos`, `science`
- `engines` — e.g. `google`, `duckduckgo`, `wikipedia`
- `language` — e.g. `en`, `de`, `fr`
- `pageno` — page number for pagination (starts at 1)

Example with categories: `curl -s "http://localhost:8080/search?q=bitcoin&format=json&categories=news"`

## If SearXNG Is Not Running

If `curl` returns "connection refused" or similar, the Docker container needs to be started or installed. Read `install.md` in this skill directory for full setup instructions.

## If Queries Return Errors

If the search returns unexpected errors or empty results, read `troubleshoot.md` in this skill directory for diagnosis steps.
