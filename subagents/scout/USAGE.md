# scout

Searches the web for high-quality sources on a research topic and returns a curated source list for collection.

## Use When

- Starting any deep research workflow.
- A topic needs fresh source discovery before collection or synthesis.
- Existing source coverage is thin and more leads are needed.

## Task Shape

Send a concise research topic or question.

```text
Research topic: <topic or question>
```

## Output Contract

Returns:

- `### Topic` with a one-line summary of the search target.
- `### Sources` as a numbered list of titles, URLs, and relevance notes.
- `### Search Notes` with queries used, gaps, and suggested follow-up searches.

The orchestrator should parse the numbered source list and dispatch one `collector` task per URL.

