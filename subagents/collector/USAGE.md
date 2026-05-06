# collector

Fetches one URL with browser-control (`$B`), extracts the main content, saves cleaned markdown to `sources/`, and saves a screenshot to `screenshots/`.

## Use When

- The `scout` has returned URLs that need to be fetched.
- A single source needs to be captured for later synthesis.

## Task Shape

Dispatch collectors in parallel, one task per URL. Include a unique collector number.

```text
Collector #<n>: Fetch and clean this source:
- URL: <url>
- Title: <title>
- Relevance: <why this source matters>
```

## Output Contract

Creates:

- `sources/<slug>.md` with YAML frontmatter for URL, title, fetch time, and screenshot path.
- `screenshots/<slug>.png`.

Returns a `### Collected` confirmation with file path, screenshot path, title, URL, summary, approximate word count, and issues encountered.

## Notes

- Run multiple collectors in parallel for speed.
- Continue the workflow if one collector fails, but note the failed URL.
