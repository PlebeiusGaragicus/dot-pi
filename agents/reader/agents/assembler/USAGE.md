# assembler

Reads page markdown files in order and produces document-level markdown outputs.

## Use When

- OCR is complete and the user wants a whole-document transcript.
- The user asks for a summary based on OCRed pages.

## Task Shape

```text
Assemble the document:
- Pages directory: pages
- Output transcript: document.md
- Output summary: summary.md if requested
```

## Output Contract

Creates or replaces:

- `document.md`
- `summary.md` only when requested

Returns `### Assembled` with output paths, page count, skipped pages, and remaining quality issues.
