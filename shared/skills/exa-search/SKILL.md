---
name: exa-search
description: Search and retrieve web content with Exa's AI-oriented search API. Use for live web research, source discovery, similar-page discovery, and token-efficient page excerpts.
disable-model-invocation: false
---

# Exa CLI

Use the scripts in `scripts/` for Exa web search. They read the API key from `EXA_API_KEY` first, then `$DOT_PI_OVERLAY/.exa.env`, then repo-root `.exa.env` as a development fallback. If no key is configured, ask the user to run `/exa-api-key`, export `EXA_API_KEY`, or create `$DOT_PI_OVERLAY/.exa.env`.

Run commands from this skill directory unless you provide an absolute script path. The scripts are intentionally verbose on failure: missing keys, unknown options, missing option values, and Exa HTTP errors print a specific `Error:` line to stderr and exit nonzero.

## Commands

Always invoke scripts by path from this skill directory:

```bash
node scripts/exa-search.js "query" --num 8
node scripts/exa-contents.js https://example.com --highlights "what to extract"
node scripts/exa-similar.js https://example.com --num 8
```

Add `--json` to any command when raw machine-readable output is more useful than the default readable text.

## Search

Use `exa-search.js` first to find candidate sources:

```bash
node scripts/exa-search.js "recent AI search APIs" --num 5
node scripts/exa-search.js "transformer architecture survey" --category "research paper"
node scripts/exa-search.js "AI regulation update" --category news --date-after 2026-01-01
```

Options:

- `--num N`: result count, default 10, max 10.
- `--type TYPE`: `auto`, `fast`, `instant`, `deep-lite`, `deep`, or `deep-reasoning`.
- `--category TYPE`: Exa category such as `news`, `research paper`, `company`, `people`, `personal site`, or `financial report`.
- `--date-after YYYY-MM-DD` / `--date-before YYYY-MM-DD`: publication-date filters.
- `--highlights "query"`: include focused excerpts in search results.
- `--text`: include page text capped to 10000 characters per result.
- `--json`: print the raw Exa API response.

## Contents

Use `exa-contents.js` after search to inspect only the URLs that matter:

```bash
node scripts/exa-contents.js https://url1.example https://url2.example --highlights "pricing limits"
node scripts/exa-contents.js https://url.example --text
```

Prefer `--highlights` for targeted facts and multi-source research. Use `--text` when the full page context matters.

## Similar Pages

Use `exa-similar.js` to find related sources from a known-good URL:

```bash
node scripts/exa-similar.js https://example.com/article --num 5
```

## Workflow

1. Search with 6-10 results unless the task clearly needs broader coverage.
2. Fetch highlights for the most relevant URLs instead of fetching full text by default.
3. Fetch full text only for sources worth reading deeply.
4. Cite URLs from the script output in the final answer.
5. Stop when results converge; repeated Exa calls cost credits.

## Failure Handling

- If a script exits nonzero, read stderr before retrying.
- If the error says the API key is missing, ask the user to configure it instead of guessing.
- If Exa returns an HTTP error, report the status and provider message to the user.
- If output is too verbose, retry with fewer results or use `--highlights` instead of `--text`.
