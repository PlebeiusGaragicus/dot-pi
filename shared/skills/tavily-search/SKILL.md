---
name: tavily-search
description: Search and extract live web content with Tavily using scripts. Use for current web research, source discovery, news, vendor docs, and citation-backed synthesis.
disable-model-invocation: false
---

# Tavily CLI

Use the scripts in `scripts/` for Tavily web search and extraction. They read the API key from `TAVILY_API_KEY` first, then `$DOT_PI_OVERLAY/.tavily.env`, then repo-root `.tavily.env` as a development fallback. If no key is configured, ask the user to run `/tavily-api-key`, export `TAVILY_API_KEY`, or create `$DOT_PI_OVERLAY/.tavily.env`.

Run commands from this skill directory unless you provide an absolute script path. The scripts are intentionally verbose on failure: missing keys, unknown options, missing option values, rate limits, plan limits, and Tavily HTTP errors print a specific `Error:` line to stderr and exit nonzero.

## Commands

Always invoke scripts by path from this skill directory:

```bash
node scripts/tavily-search.js "query" --num 8
node scripts/tavily-search.js "latest AI regulation" --topic news --time-range week
node scripts/tavily-extract.js https://example.com/article --max-chars 4000
```

Add `--json` to either command when raw machine-readable output is more useful than the default readable text.

## Search

Use `tavily-search.js` first to find candidate sources:

```bash
node scripts/tavily-search.js "recent AI search APIs" --num 5
node scripts/tavily-search.js "NVIDIA earnings guidance" --topic finance --time-range month
node scripts/tavily-search.js "California AI safety law update" --topic news --time-range week
```

Options:

- `--num N`: result count, default 10, max 20.
- `--topic TYPE`: `general`, `news`, or `finance`.
- `--time-range RANGE`: `day`, `week`, `month`, or `year`.
- `--search-depth DEPTH`: `basic` or `advanced`; default `basic`. Use `advanced` only when basic results are clearly insufficient because it can cost more credits.
- `--max-raw-chars N`: max raw excerpt characters per result, default 2000.
- `--json`: print the raw Tavily API response.

The search script always requests raw page content, disables Tavily's generated answer, and requests usage data. Do the synthesis yourself from the returned sources.

## Extract

Use `tavily-extract.js` after search when one or more URLs are worth reading more deeply:

```bash
node scripts/tavily-extract.js https://url1.example https://url2.example
node scripts/tavily-extract.js https://example.com/report --depth advanced --max-chars 8000
```

Options:

- `--depth DEPTH`: `basic` or `advanced`; default `basic`.
- `--max-chars N`: max content characters per URL in readable output, default 6000.
- `--json`: print the raw Tavily API response.

## Workflow

1. Search with 5-10 results unless the task clearly needs broader coverage.
2. Add `--topic news` and `--time-range` when freshness matters.
3. Extract only the URLs that look authoritative or unusually relevant.
4. Cite URLs from the script output in the final answer.
5. Stop when results converge; repeated Tavily calls cost credits.

## Failure Handling

- If a script exits nonzero, read stderr before retrying.
- If the error says the API key is missing, ask the user to configure it instead of guessing.
- If Tavily returns HTTP 429, report the retry guidance and avoid immediate repeated calls.
- If Tavily returns a plan or credit limit error, tell the user and stop searching.
- If output is too verbose, retry with fewer results or a lower character cap.
