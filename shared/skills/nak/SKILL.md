---
name: nak
description: "Read this skill file to learn the nak commands for interacting with the Nostr protocol. Use the bash tool to run nak — there is no nak tool, only bash."
allowed-tools: Bash
---

# nak — the nostr army knife

Use the `bash` tool to run `nak` commands. It is already installed at `/opt/homebrew/bin/nak`.

## Query Events from Relays

```bash
nak req -k 1 -l 5 wss://relay.abvstudio.net
```

Key flags for `nak req`:
- `-k <kind>` — filter by event kind (1=note, 0=profile, 3=contacts, 30023=article)
- `-a <pubkey>` — filter by author (hex pubkey, npub, or nip-05)
- `-l <n>` — limit number of results
- `-t <tag>=<value>` — filter by tag (e.g. `-t t=bitcoin`)
- `--search <query>` — NIP-50 full-text search (relay must support it)
- `--stream` — keep subscription open for live events

Pipe through `jq` for readable output:

```bash
nak req -k 1 -a npub1... -l 3 wss://relay.abvstudio.net | jq '{content, created_at}'
```

## Fetch by NIP-19 Code

```bash
nak fetch nevent1...
nak fetch nprofile1...
nak fetch user@domain.com
```

Automatically resolves relay hints and outbox relays.

## View a Profile

```bash
nak profile npub1...
nak profile user@domain.com
```

## Decode / Encode NIP-19

```bash
nak decode npub1...
nak decode nevent1...
nak encode npub <hex-pubkey>
nak encode nevent <hex-event-id>
nak encode nevent --relay wss://relay.abvstudio.net <hex-event-id>
```

## Create and Publish Events

```bash
nak event -c 'hello world' --sec <secret-key> wss://relay.abvstudio.net
echo "hello world" | nak publish --sec <secret-key>
```

Key flags for `nak event`:
- `-c <content>` — event content
- `-k <kind>` — event kind (default: 1)
- `-t <tag>=<value>` — add tags
- `-p <pubkey>` — add a p-tag
- `-e <event-id>` — add an e-tag
- `--sec <key>` — secret key (hex, nsec, ncryptsec, or bunker URL)
- `--pow <n>` — proof-of-work difficulty target

## Key Management

```bash
nak key generate
nak key public <secret-key-hex>
nak encode nsec <secret-key-hex>
nak key encrypt <secret-key-hex> <password>
nak key decrypt <ncryptsec> <password>
```

## Other Useful Commands

- `nak relay wss://relay.abvstudio.net` — get relay info document
- `nak verify` — verify event hash and signature (pipe event JSON via stdin)
- `nak nip <number>` — show description of a NIP
- `nak count -k 1 -a <pubkey> wss://relay.abvstudio.net` — count matching events

## Important Notes

- Always use `--sec` or `$NOSTR_SECRET_KEY` for signing. Never expose secret keys in output.
- Most commands accept npub/nevent/nprofile codes directly — no need to decode first.
- Pipe results through `jq` for filtering and formatting.
- Add `-q` flag to suppress informational stderr output when piping.

## If nak Is Not Installed

Read `install.md` in this skill directory for installation instructions.
