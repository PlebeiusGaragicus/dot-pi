---
name: searxng
description: "Search the internet via a local SearXNG instance. Returns JSON results with titles, URLs, and snippets — no API key required."
---

# SearXNG Skill

Query a locally-running [SearXNG](https://github.com/searxng/searxng) instance for internet search results. Returns structured JSON with titles, URLs, and text snippets. No authentication required.

## Prerequisites

- **Docker** — `brew install --cask docker` (launch Docker Desktop at least once)
- **jq** — `brew install jq`

## Installation

```bash
# Pull the image
docker pull searxng/searxng

# Create settings directory
mkdir -p ~/searxng
```

Write `~/searxng/settings.yml`:

```yaml
use_default_settings: true

server:
  secret_key: "CHANGE_ME"   # generate: openssl rand -hex 32
  limiter: false              # disable rate limiting for agent use

search:
  formats:
    - html
    - json
```

Generate a real secret key:

```bash
SECRET=$(openssl rand -hex 32)
sed -i '' "s/CHANGE_ME/$SECRET/" ~/searxng/settings.yml
```

Start the container:

```bash
docker run -d -p 8080:8080 --name searxng --restart always \
  -v ~/searxng/settings.yml:/etc/searxng/settings.yml:ro \
  searxng/searxng
```

## Usage

```bash
curl -s "http://localhost:8080/search?q=python+asyncio&format=json" \
  | jq '.results[:5] | .[] | {title, url, content}'
```

Just URLs:

```bash
curl -s "http://localhost:8080/search?q=rust+borrow+checker&format=json" \
  | jq -r '.results[:5] | .[].url'
```

## Endpoint Reference

| Field        | Value                                              |
|--------------|----------------------------------------------------|
| **URL**      | `http://localhost:8080/search`                     |
| **Method**   | GET                                                |
| **Required** | `q` (query), `format=json`                         |
| **Optional** | `categories`, `engines`, `language`, `pageno`      |

Response shape:

```json
{
  "query": "...",
  "results": [
    {
      "title": "...",
      "url": "https://...",
      "content": "snippet text...",
      "engine": "google",
      "score": 1.0
    }
  ]
}
```

Useful fields per result: `title`, `url`, `content`, `engine`, `score`.

## Container Management

```bash
docker start searxng
docker stop searxng
docker restart searxng       # after settings changes
docker logs -f searxng
docker rm -f searxng          # remove entirely
```

Update:

```bash
docker rm -f searxng
docker pull searxng/searxng
# re-run the docker run command above
```

## Notes

- The `json` format must be listed in `settings.yml` or the API rejects `format=json` requests.
- `limiter: false` prevents bot-detection rate limiting from blocking agent queries.
- Default port is 8080; change both the `-p` flag and query URL if you need a different port.
