---
name: nostr-nak
description: Use the Nostr Army Knife (nak) CLI to query relays, fetch NIP-19 events/profiles, inspect Nostr metadata, decode identifiers, and publish signed events. Use when working with Nostr, npub/nevent/nprofile/note IDs, relays, or nak commands.
disable-model-invocation: false
---

# nostr-nak

Use the `bash` tool to run the Nostr Army Knife (`nak`) CLI. There is no dedicated `nak` tool.

## Command Wrapper

`nak` can hang in non-interactive environments due to stdout buffering. Wrap `nak` commands with `script` unless using a clearly non-streaming command that has already behaved safely in this environment:

```bash
script -q -c 'nak req -k 1 -l 5 wss://relay.damus.io' /dev/null | cat
```

Use single quotes around the `script -c` command unless the command itself needs shell interpolation.

## Relays

Use these fallback discovery relays when the user does not specify relays:

- `wss://relay.damus.io`
- `wss://relay.primal.net`
- `wss://relay.nostr.band`

If the user specifies a relay, use their relay instead.

## Query Events

Use `nak req` to query events from relays:

```bash
script -q -c 'nak req -k 1 -l 5 wss://relay.damus.io wss://relay.primal.net' /dev/null | cat
script -q -c 'nak req -k 1 -a npub1... -l 3 wss://relay.damus.io' /dev/null | cat
```

Key flags for `nak req`:

- `-k <kind>`: filter by event kind (`1` note, `0` profile, `3` contacts, `30023` article).
- `-a <pubkey>`: filter by author using a hex pubkey, `npub`, or NIP-05 name.
- `-l <n>`: limit result count.
- `-t <tag>=<value>`: filter by tag, e.g. `-t t=bitcoin`.
- `--search <query>`: NIP-50 full-text search; relay support varies.
- `--stream`: keep the subscription open for live events. Use only when the user explicitly asks for live streaming.
- `-q`: suppress informational stderr output when piping.

Pipe through `jq` when you need compact fields:

```bash
script -q -c 'nak req -q -k 1 -a npub1... -l 3 wss://relay.damus.io' /dev/null | jq '{content, created_at}'
```

## Fetch Nostr Identifiers

Use `nak fetch` for NIP-19 codes and NIP-05 identifiers. It resolves relay hints and outbox relays when available:

```bash
script -q -c 'nak fetch nevent1...' /dev/null | cat
script -q -c 'nak fetch nprofile1...' /dev/null | cat
script -q -c 'nak fetch user@domain.com' /dev/null | cat
```

Use `nak profile` when the user specifically asks for a profile:

```bash
script -q -c 'nak profile npub1...' /dev/null | cat
script -q -c 'nak profile user@domain.com' /dev/null | cat
```

## Decode and Encode NIP-19

```bash
script -q -c 'nak decode npub1...' /dev/null | cat
script -q -c 'nak decode nevent1...' /dev/null | cat
script -q -c 'nak encode npub <hex-pubkey>' /dev/null | cat
script -q -c 'nak encode nevent --relay wss://relay.damus.io <hex-event-id>' /dev/null | cat
```

Most commands accept `npub`, `nevent`, `nprofile`, and NIP-05 identifiers directly, so decode only when the decoded fields matter.

## Publish Events

Do not publish or sign events unless the user explicitly asks. Never print secret keys.

```bash
script -q -c "nak event -c 'hello world' --sec <secret-key> wss://relay.damus.io" /dev/null | cat
script -q -c "printf '%s\n' 'hello world' | nak publish --sec <secret-key> wss://relay.damus.io" /dev/null | cat
```

Key flags for `nak event`:

- `-c <content>`: event content.
- `-k <kind>`: event kind; default is `1`.
- `-t <tag>=<value>`: add a tag.
- `-p <pubkey>`: add a `p` tag.
- `-e <event-id>`: add an `e` tag.
- `--sec <key>`: signing key as hex, `nsec`, `ncryptsec`, bunker URL, or `$NOSTR_SECRET_KEY`.
- `--pow <n>`: proof-of-work difficulty target.

## Key Management

Use key commands only when the user asks for key work. Never expose private keys in the final answer.

```bash
script -q -c 'nak key generate' /dev/null | cat
script -q -c 'nak key public <secret-key-hex>' /dev/null | cat
script -q -c 'nak encode nsec <secret-key-hex>' /dev/null | cat
script -q -c 'nak key encrypt <secret-key-hex> <password>' /dev/null | cat
script -q -c 'nak key decrypt <ncryptsec> <password>' /dev/null | cat
```

## Other Useful Commands

- `script -q -c 'nak relay wss://relay.damus.io' /dev/null | cat`: get a relay information document.
- `script -q -c 'nak verify' /dev/null | cat`: verify event hash and signature; pipe event JSON via stdin.
- `script -q -c 'nak nip <number>' /dev/null | cat`: show a NIP description.
- `script -q -c 'nak count -k 1 -a <pubkey> wss://relay.damus.io' /dev/null | cat`: count matching events.

## Output Guidance

- For user-facing summaries, extract the relevant fields instead of dumping raw event JSON.
- Convert Unix `created_at` timestamps to readable dates when discussing recency.
- Cite relays and event IDs when they matter for reproducibility.
- If a relay returns nothing, try one or two fallback relays rather than looping.

## If nak Is Not Installed

Read `install.md` in this skill directory for installation instructions.
