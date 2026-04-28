# Reader MAS

PDF OCR with durable page artifacts. Reader operates in workspace mode so each PDF run gets a dated directory with page images, page markdown, and resumable session logs.

## Orchestrator

The orchestrator has restricted tools (`read,find,ls,grep,subagent` via `pi-args`) and disables context-file discovery with `--no-context-files`. It cannot render PDFs or OCR pages directly; it inspects workspace artifacts and delegates all work through subagents.

Reader owns its top-level workflow in `SYSTEM.md`. Subagents live under `agents/reader/agents/`, and `agent-orchestrator` appends each subagent's `USAGE.md` contract to the parent prompt.

## Subagents

### ingester

| Field | Value |
|-------|-------|
| Tools | bash, read, write, ls |
| Resource pool | local |

Renders one PDF into zero-padded PNG files under `pages/` and writes `reader-manifest.json`. It prefers Poppler (`pdfinfo`, `pdftoppm`) and falls back to ImageMagick when available.

### ocr-page

| Field | Value |
|-------|-------|
| Tools | read, write, ls |
| Model | vision-capable model recommended |
| Resource pool | api |

OCRs exactly one page image and writes exactly one markdown file beside it. The page markdown includes YAML frontmatter with page number, image path, OCR status, confidence, review flag, and warnings.

### page-auditor

| Field | Value |
|-------|-------|
| Tools | read, write, ls |
| Model | vision-capable model recommended |
| Resource pool | api |

Reviews one uncertain page transcription against the source image and replaces that page's markdown with corrected content.

### assembler

| Field | Value |
|-------|-------|
| Tools | read, find, ls, write |
| Skills | none |
| Resource pool | local |

Reads page markdown files in order and produces `document.md`, plus `summary.md` when requested. It does not OCR images or modify page files.

## Workflow

The standard pipeline is:

1. **ingester** (single) -- renders PDF pages to `pages/page-0001.png` and writes `reader-manifest.json`.
2. **ocr-page** (parallel) -- transcribes one page image per worker to `pages/page-0001.md`.
3. **page-auditor** (selective) -- reruns only pages marked uncertain, low-confidence, empty, or structurally difficult.
4. **assembler** (single, optional) -- assembles all page markdown into `document.md` and optionally `summary.md`.

On resume, the orchestrator inspects the manifest and `pages/` first. Existing page images are reused, and only missing or failed markdown files are sent back through OCR.

## Workspace Structure

Each run creates a dated directory under `workspaces/reader/`:

```
workspaces/reader/2026-04-28-101500/
├── pages/
│   ├── page-0001.png
│   ├── page-0001.md
│   ├── page-0002.png
│   └── page-0002.md
├── sessions/
├── reader-manifest.json
├── document.md
└── summary.md
```

## Configuration

Runtime configuration is file-based:

| File | Purpose |
|------|---------|
| `workspace.conf` | Lists workspace directories to pre-create (`pages`, `sessions`) |
| `SYSTEM.md` | Orchestrator workflow and resume policy |
| `pi-args` | Orchestrator tool restrictions and `--no-context-files` |
| `extensions/reasoning-off-shim` | Common top-level extension link for explicit OpenAI-compatible reasoning disable behavior |
| `agents/*/extensions/reasoning-off-shim` | Subagent extension bundle link for the same provider-request shim |
| `agents/ocr-page/pi-args` | Restricts OCR workers to page read/write tools |

For OCR, configure a vision-capable default model, or add `--model ${VISION_MODEL}` to the OCR subagents' `pi-args` after assigning `VISION_MODEL` through `dotpi setup` / `model_roles`. If OCR runs against a local model instead of an API-backed model, change `ocr-page/resource-pool.conf` and `page-auditor/resource-pool.conf` from `api` to `local`.

Reader gets `reasoning-off-shim` through the standard top-level extension bundle, and reader subagents get it through the subagent extension bundle. Run `dotpi sync` after adding a reader subagent so its default subagent extensions are wired.

## Usage

```bash
# Start a new PDF OCR run
reader "/path/to/document.pdf"

# Start a named workspace
reader - annual report 2025

# List past reader workspaces
reader --list

# Resume the latest reader workspace
reader --resume

# Resume a specific workspace by prefix
reader --resume 2026-04-28
```
