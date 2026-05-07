# mas

Top-level multi-agent orchestrator for reusable capability agents.

Unlike workflow-specific MAS configs that own a nested worker pool, `mas` delegates to a fixed set of durable top-level agents:

- `ask` - chat-only reasoning, classification, critique, and PASS/FAIL checks.
- `scout` - read-only directory and repository exploration.
- `writer` - documentation, prose editing, reports, and other text artifacts.
- `coder` - implementation, tests, builds, and command execution.
- `web` - live web search, browser-control, source extraction, and citation-backed synthesis.

Workflow prompts in `prompts/` define task-specific orchestration. For example, `/deepresearch` can ask `web` to find and inspect sources, `writer` to create a report, and `ask` with the `judge` persona to validate quality gates. `/pdf-ocr` drives PDF ingestion, per-page OCR via `coder`, optional assembly via `writer`, and URL fetch via `web` when needed; page renders go under `pages-png/` and transcripts under `pages-ocr/`. `/workflow-builder` helps create or revise project-local workflows under `.pi/prompts/`. The workers remain general-purpose capability agents.

Worker traces are grouped under `subagent-traces/<run-id>/` with a manifest for retrospective inspection. User-resumable `mas` sessions remain separate in `sessions/`.
