---
name: exa-search
description: Search and retrieve web content with Exa's AI-oriented search API. Use for live web research, source discovery, similar-page discovery, and token-efficient page excerpts.
disable-model-invocation: false
---

# Exa Search

Use the scripts in `scripts/` for Exa web search. They read the API key from `EXA_API_KEY` first, then repo-root `.exa.env`. If no key is configured, ask the user to run `/exa-api-key` or export `EXA_API_KEY`.

## Commands

Always invoke scripts by path from this skill directory:

```bash
node scripts/exa-search.js "query" --num 8
node scripts/exa-contents.js https://example.com --highlights "what to extract"
node scripts/exa-similar.js https://example.com --num 8
```

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
