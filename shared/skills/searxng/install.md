# SearXNG Installation

## Prerequisites

- **Docker** — `brew install --cask docker` (launch Docker Desktop at least once)
- **jq** — `brew install jq`

## Setup

Pull the image and create a settings directory:

```bash
docker pull searxng/searxng
mkdir -p ~/searxng
```

Write `~/searxng/settings.yml` with the following content:

```yaml
use_default_settings: true

server:
  secret_key: "CHANGE_ME"
  limiter: false

search:
  formats:
    - html
    - json
```

Generate a real secret key and apply it:

```bash
SECRET=$(openssl rand -hex 32)
sed -i '' "s/CHANGE_ME/$SECRET/" ~/searxng/settings.yml
```

## Start the Container

```bash
docker run -d -p 8080:8080 --name searxng --restart always \
  -v ~/searxng/settings.yml:/etc/searxng/settings.yml:ro \
  searxng/searxng
```

## Verify

Confirm SearXNG is running:

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | jq '.results[:1]'
```

You should see a JSON array with at least one result object.
