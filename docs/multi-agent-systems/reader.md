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
| Model | `$DEFAULT_AGENTIC_MODEL` |

Renders one PDF into zero-padded PNG files under `pages/` and writes `reader-manifest.json`. It prefers Poppler (`pdfinfo`, `pdftoppm`) and falls back to ImageMagick when available.

### ocr-page

| Field | Value |
|-------|-------|
| Tools | read, write, ls |
| Model | `$DEFAULT_VLM_MODEL` |

OCRs exactly one page image and writes exactly one markdown file beside it. The page markdown includes YAML frontmatter with page number, image path, OCR status, confidence, review flag, and warnings.

### page-auditor

| Field | Value |
|-------|-------|
| Tools | read, write, ls |
| Model | `$DEFAULT_VLM_MODEL` |

Reviews one uncertain page transcription against the source image and replaces that page's markdown with corrected content.

### assembler

| Field | Value |
|-------|-------|
| Tools | read, find, ls, write |
| Skills | none |
| Model | `$DEFAULT_AGENTIC_MODEL` |

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
| `bootstrap.sh` | Marks the agent as workspace-mode and creates `pages` and `sessions` before pi starts |
| `SYSTEM.md` | Orchestrator workflow and resume policy |
| `pi-args` | Orchestrator tool restrictions and `--no-context-files` |
| `extensions/reasoning-off-shim` | Common top-level extension link for explicit OpenAI-compatible reasoning disable behavior |
| `agents/*/extensions/reasoning-off-shim` | Subagent extension bundle link for the same provider-request shim |
| `agents/ocr-page/pi-args` | Restricts OCR workers to page read/write tools |

For OCR, configure `DEFAULT_VLM_MODEL` with `dotpi models`, or use `/model-default` from an OCR subagent context for a subagent-local `.model` override. The OCR subagents reference `$DEFAULT_VLM_MODEL` from their `pi-args`. If the resolved provider is listed in `local-providers.conf`, OCR is throttled by the local limit in `agent-orchestrator.conf`; otherwise it is treated as API-backed and unbounded.

Reader gets `reasoning-off-shim` through the standard top-level extension bundle, and reader subagents get it through the subagent extension bundle. Run `dotpi sync` after adding a reader subagent so its default subagent extensions are wired.

## Usage

```bash
# Start a new PDF OCR run
reader - "/path/to/document.pdf"

# Start a named workspace
reader -n annual-report-2025 - "/path/to/document.pdf"

# List past reader workspaces
reader ls

# Choose a reader workspace to resume
reader resume

# Resume a specific workspace by exact basename
reader resume 2026-04-28-091500
```
