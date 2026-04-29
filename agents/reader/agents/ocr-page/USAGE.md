# ocr-page

Transcribes exactly one page image into exactly one markdown file.

## Use When

- A `pages/page-NNNN.png` file exists and the matching `.md` file is missing.
- A page manifest entry has `ocr_status: pending` or `failed`.

## Task Shape

Dispatch one task per page. Tasks may be logically parallel.

```text
OCR one page:
- Page: <number>
- Image: pages/page-0001.png
- Output: pages/page-0001.md
```

## Output Contract

Creates or replaces:

- `pages/page-0001.md`

Returns `### OCR Complete` with page number, output path, confidence, warnings, and whether the page needs audit.
