# ingester

Renders a PDF into page images and records ingestion state in `reader-manifest.json`.

## Use When

- Starting a reader workspace that has no `reader-manifest.json`.
- Page images are missing or the user explicitly asks to re-ingest.

## Task Shape

Provide the PDF path and whether existing page images should be reused.

```text
Ingest this PDF:
- PDF path: <absolute-or-workspace-relative-path>
- Re-ingest existing images: no
```

## Output Contract

Creates or updates:

- `pages/page-0001.png`, `pages/page-0002.png`, etc.
- `reader-manifest.json` in the workspace root.

Returns `### Ingested` with source PDF path, page count, render command, files created/skipped, and any dependency or rendering issues.
