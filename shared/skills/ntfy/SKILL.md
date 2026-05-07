---
name: ntfy
description: Send push notifications via a private or self-hosted ntfy server using repo-root .ntfy.env (NTFY_BASE_URL, optional Basic auth).
disable-model-invocation: false
---

# ntfy notifications

Use when the user wants **push notifications** on phone or desktop via [ntfy](https://ntfy.sh/). Scripts read **`NTFY_BASE_URL`** first from the environment, then from repo-root **`.ntfy.env`**. Optional **`NTFY_USER`** and **`NTFY_PASSWORD`** enable HTTP Basic auth (typical for private servers).

Run commands from this skill directory unless you use absolute paths to the scripts. **`DOT_PI_DIR`** must be set (dispatch-agent sets it when launching pi from this repo); scripts exit with a clear error if it is missing.

If nothing is configured, ask the user to export `NTFY_BASE_URL` or create **`.ntfy.env`** at the dot-pi repo root:

```bash
NTFY_BASE_URL=https://ntfy.example.com
NTFY_USER=myuser
NTFY_PASSWORD=mypass
```

Leave `NTFY_USER` and `NTFY_PASSWORD` empty for anonymous/public publish (only if the server allows it).

The file follows the same **`.service-name.env`** convention as `.exa.env` / `.tavily.env` and is gitignored via `.*.env`.

## Commands

Always invoke from this skill directory:

```bash
node scripts/ntfy-send.js <topic> <message text...>
echo "Build finished" | node scripts/ntfy-send.js ci-alerts
node scripts/ntfy-send.js alerts "Deploy OK" --title "Production" --priority 5 --tags warning,deploy
```

Options:

- `--title TEXT` — notification title (ntfy `Title` header).
- `--priority N` — integer **1** (lowest) through **5** (highest).
- `--tags LIST` — comma-separated tags (ntfy `Tags` header).

Scripts print specific **`Error:`** lines on failure (missing config, HTTP 401/403/404, other HTTP errors).

## curl fallback

If Node is unavailable, publish with curl (same variables). Topic URL must be encoded if it contains reserved characters:

```bash
curl -u "${NTFY_USER}:${NTFY_PASSWORD}" \
  -d "Message body" \
  -H "Title: Optional title" \
  -H "Priority: 5" \
  "${NTFY_BASE_URL}/my-topic"
```

Omit `-u` when not using Basic auth.
