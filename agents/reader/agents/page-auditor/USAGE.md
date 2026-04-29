# page-auditor

Verifies one OCR markdown file against its page image and fixes only that page.

## Use When

- `ocr-page` reports low confidence.
- The page markdown is empty, uncertain, or has warnings for dense tables, diagrams, handwriting, stamps, or rotated scans.

## Task Shape

```text
Audit one page:
- Page: <number>
- Image: pages/page-0001.png
- Markdown: pages/page-0001.md
```

## Output Contract

Creates or replaces:

- The same page markdown file.

Returns `### Page Audited` with page number, file path, changes made, confidence, and remaining issues.
