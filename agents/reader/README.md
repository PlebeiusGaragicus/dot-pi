# reader

Reader is a workspace multi-agent system for PDF OCR. It renders a PDF into per-page images, OCRs each page with a vision model, and stores durable markdown beside each page image so interrupted runs can resume without re-ingesting the PDF.

## Usage

```
reader "/path/to/file.pdf"           # new workspace session
reader - annual report 2025          # named workspace session
reader --list                        # list past reader workspaces
reader --resume                      # resume latest workspace
reader --resume 2026-04-28           # resume matching workspace prefix
reader -h                            # show this help
```

## Workspace Output

Each run creates `workspaces/reader/<timestamp>/` with:

- `pages/page-0001.png` and `pages/page-0001.md` pairs.
- `reader-manifest.json` for PDF metadata, render settings, page paths, and OCR status.
- `document.md` when the page markdown is assembled into one document.
- `summary.md` when a concise summary is requested.
- `sessions/` with the orchestrator and subagent session logs.

Reader OCR workers should run on a vision-capable model. Configure `DEFAULT_VLM_MODEL` with `dotpi model-defaults`, or use `/model-default` for a local `.model` override. The OCR subagents reference `$DEFAULT_VLM_MODEL` from their `pi-args`.
