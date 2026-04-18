# SearXNG Troubleshooting

## Quick Health Check

```bash
curl -s "http://localhost:8080/search?q=test&format=json" | jq '.results[:1]'
```

If this returns results, SearXNG is working correctly.

## Connection Refused

The container is not running. Start it:

```bash
docker start searxng
```

If the container does not exist, follow `install.md` in this directory.

## "format=json" Rejected (403 or HTML response)

The `json` format is not enabled in settings. Verify `~/searxng/settings.yml` contains:

```yaml
search:
  formats:
    - html
    - json
```

After editing, restart the container:

```bash
docker restart searxng
```

## Empty Results or Rate Limiting

Verify `limiter: false` is set in `~/searxng/settings.yml` under the `server` section. Restart after changes:

```bash
docker restart searxng
```

## Container Management

```bash
docker start searxng        # start stopped container
docker stop searxng         # stop container
docker restart searxng      # restart after config changes
docker logs -f searxng      # view logs
docker rm -f searxng        # remove container entirely
```

## Updating SearXNG

```bash
docker rm -f searxng
docker pull searxng/searxng
docker run -d -p 8080:8080 --name searxng --restart always \
  -v ~/searxng/settings.yml:/etc/searxng/settings.yml:ro \
  searxng/searxng
```

## Port Conflicts

Default port is 8080. If another service uses that port, change both the `-p` flag in the `docker run` command and the URL in your curl queries to match.
