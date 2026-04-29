# Usage Guide

This guide walks through concrete examples of how to use dot-pi day-to-day.

## Prerequisites

You have pi installed, the repo cloned to `~/.dot-pi`, and your shell configured:

```bash
export PATH="$HOME/.dot-pi/bin:$PATH"
source "$HOME/.dot-pi/env.sh"
```

## 1. Recon a Codebase

You're dropped into an unfamiliar project and need to understand it fast.

```bash
cd ~/projects/some-api
recon "Map the authentication flow -- which files handle login, session management, and token refresh?"
```

**What happens:** pi starts with the recon MAS config. The orchestrator can use the `subagent` tool to delegate to specialized agents. A typical flow:

1. The LLM calls `subagent` with `{ agent: "scout", task: "Find all authentication-related code..." }`
2. Scout (Haiku, fast and cheap) greps for auth patterns, reads key files, and returns a structured summary with file paths and line ranges
3. The LLM reads the summary and either answers you directly or delegates to planner for a deeper analysis

### Using the `/implement` prompt template

If you want the scout-plan chain in one shot:

```bash
recon
> /implement add rate limiting to the /api/login endpoint
```

This triggers a two-step chain:

1. **scout** finds all code relevant to the login endpoint
2. **planner** creates a numbered implementation plan from the scout's findings

Each step runs in its own isolated pi process. The output of each step flows into the next via the `{previous}` placeholder.

## 2. Implement and Review

You know what needs to change and want the work done with a review pass.

```bash
cd ~/projects/some-api
impl
> /implement-and-review add input validation to all POST endpoints in src/routes/
```

This triggers:

1. **worker** implements the changes (has full read/write/edit/bash access)
2. **reviewer** reviews the diff (read-only, uses `git diff` to inspect changes)
3. **worker** applies the review feedback

Or skip the prompt template and talk to the orchestrator directly:

```bash
impl "Fix the race condition in src/queue/processor.ts -- the dequeue and ack aren't atomic"
```

The LLM decides how to use the available agents. It might send the task straight to worker, or ask reviewer to inspect the area first.

## 3. Write a Blog Post

You want to write a technical blog post about a project you're working on.

```bash
cd ~/projects/my-cool-library
blog
> /research-write-edit how this library's plugin system works and why we chose that architecture
```

This chains three agents:

1. **researcher** (Haiku) explores the codebase, gathers key facts, code examples, and suggests angles
2. **writer** (Sonnet) drafts an 800-1500 word blog post from the research
3. **editor** (Sonnet) reviews for accuracy, clarity, and structure, then returns a polished draft

For a quicker loop when you already know the material:

```bash
blog
> /write-and-edit 5 practical tips for writing maintainable TypeScript
```

This skips research and goes straight to write-review-revise.

## 4. Deep Research (Workspace MAS)

Workspace MAS configs launch in a fresh dated directory so artifacts stay isolated.

```bash
deepresearch "What are the latest developments in WebTransport protocol?"
```

**What happens:** `deepresearch` creates `workspaces/deepresearch/<timestamp>/` with `sources/`, `screenshots/`, and `sessions/` subdirectories, then launches pi inside it. The orchestrator's `SYSTEM.md` requires research, collection, writing, and editing to go through subagents. Both the orchestrator and all subagent sessions are stored in `sessions/` for unified trajectory analysis. The orchestrator runs a four-step pipeline:

1. **scout** searches the web via Tavily API for relevant sources
2. **collector** (parallel, one per URL) fetches each page via headless browser, strips boilerplate, saves to `sources/`
3. **writer** reads all sources and synthesizes a structured report to `drafts/report.md`
4. **editor** reviews the draft against sources and produces `report.md`

To give a workspace a memorable name, add a lone `-` and put the name after it:

```bash
deepresearch - creatine loading protocol
```

This creates a folder like `workspaces/deepresearch/2026-04-28-091454--creatine-loading-protocol/`. Without a name, dot-pi keeps the timestamp-only folder name.

### Listing and resuming workspaces

Each run creates a new workspace. To see past runs:

```bash
deepresearch --list
```

```
Workspaces for deepresearch:
  2026-04-10-125602  (12 files)
  2026-04-10-130214  (3 files)
```

To resume the most recent workspace session:

```bash
deepresearch --resume
```

Or resume a specific one by prefix:

```bash
deepresearch --resume 2026-04-10-125602
```

This cd's into the original workspace directory (so all files are present) and opens pi's session selector.

You can also use the global picker across workspace agents:

```bash
resume
resume creatine
```

`resume` shows the 10 most recent workspaces with numbers. Extra words filter by agent name or workspace name, then you choose the number to resume.

## 5. Reader (Workspace MAS)

Reader ingests a PDF once, renders each page to an image, OCRs each page with a vision model, and keeps page markdown beside the page images for resumable work.

```bash
reader "/path/to/document.pdf"
```

**What happens:** `reader` creates `workspaces/reader/<timestamp>/` with `pages/` and `sessions/` subdirectories. The orchestrator first creates `reader-manifest.json`, then dispatches one `ocr-page` subagent per page image. Each page is stored as a pair:

```text
pages/page-0001.png
pages/page-0001.md
```

The OCR workers should run on a vision-capable model. Configure `DEFAULT_VLM_MODEL` with `dotpi model-defaults`, or use `/model-default` from an OCR subagent context for a subagent-local `.model` override. The OCR subagents reference `$DEFAULT_VLM_MODEL` from their `pi-args`. If the resolved provider is listed in `local-providers.conf`, OCR is throttled by the local limit in `agent-orchestrator.conf`; otherwise it is treated as API-backed and unbounded.

To resume without re-ingesting the PDF:

```bash
reader --resume
```

On resume, the orchestrator inspects `reader-manifest.json` and `pages/`, reuses existing page images, and only OCRs missing or failed page markdown.

### Running evals

The eval runner (`evals/run-eval.sh`) tests MAS configs against scripted prompts in non-interactive mode. Both the MAS command and a prompts file are required:

```bash
# Quick smoke test
./evals/run-eval.sh deepresearch evals/deepresearch-short.txt

# Comprehensive suite
./evals/run-eval.sh deepresearch evals/deepresearch-long.txt

# With automatic retro analysis after each prompt
./evals/run-eval.sh --with-retro deepresearch evals/deepresearch-short.txt
```

Each prompt runs in its own workspace. Results are organized by eval name (derived from the prompts filename) at `evals/results/<mas>/<eval-name>/<timestamp>/` with per-prompt output files and a JSONL manifest for trajectory analysis. When `--with-retro` is used, retro output is saved to `prompt-N-retro.txt` alongside each prompt's output.

## 6. Trajectory Analysis (Retro)

After running a workspace MAS, use the retro MAS to analyze session traces and output files for procedural issues. Retro can run on a free open-source model and produce a structured report that can be fed to a frontier model for deeper analysis.

### Interactive use

```bash
cd workspaces/deepresearch/2026-04-12-150258
retro
```

### Non-interactive use (`run-retro`)

Target a workspace directly without manual `cd`:

```bash
run-retro deepresearch                           # latest workspace
run-retro deepresearch 2026-04-12               # by date prefix
run-retro deepresearch --list                    # list workspaces
run-retro deepresearch --pick                   # interactive menu (newest first)
run-retro deepresearch -- "focus on citations"  # with steering hint
```

**What happens:** The orchestrator surveys the workspace, finds all JSONL session files, and extracts the original user task. It then dispatches two types of subagents in parallel:

1. **scanner** (one per session file) -- parses JSONL traces with jq/grep, checking for infinite loops, tool errors, failed dispatches, and protocol violations
2. **reviewer** -- inspects output files (report.md, sources/, etc.) for completeness and instruction adherence

The orchestrator synthesizes all findings into `retrospective-report.md` in the workspace directory.

### Frontier model handoff

The retro report is designed to be concise and structured -- ideal input for a paid frontier model:

```bash
# After retro writes retrospective-report.md, feed it to a stronger model
recon "Read retrospective-report.md and suggest specific prompt or code fixes for each issue"
```

This two-step pattern keeps costs low: the bulk parsing runs for free on an open-source model, and only the compact report goes to a frontier model.

## 7. Ad-hoc Single Agent Use

You don't always need prompt templates. Just describe what you want:

```bash
# Quick recon question
recon "What ORM does this project use and how are migrations handled?"

# Direct implementation
impl "Rename the User model to Account everywhere"

# Blog with specific instructions
blog "Write a short post comparing our REST and GraphQL endpoints, keep it under 600 words"
```

The orchestrator sees its available subagents and decides whether to delegate or handle the task directly.

## 8. Create a Custom MAS

Say you want a MAS for writing documentation:

```bash
# Scaffold the MAS directory (in-situ mode)
dotpi create docs-mas

# Or as a workspace MAS (creates bootstrap.sh)
dotpi create --workspace docs-mas
```

This creates `agents/docs-mas/` with extensions and models symlinked; **`skills/` is empty** until you run `dotpi link-skill docs-mas <skill>`. Now add or link subagent configs:

```bash
mkdir -p ~/.dot-pi/agents/docs-mas/agents/writer
cat > ~/.dot-pi/agents/docs-mas/agents/writer/SYSTEM.md << 'EOF'

You are a documentation writer. Read the code and produce clear, well-structured
documentation in markdown. Include code examples from the actual source.

Output format:
- Title and overview
- Sections with headers
- Code examples with language tags
- A "See also" section linking related files
EOF
```

Add `USAGE.md` to document the writer's invocation contract. The `agent-orchestrator` extension appends those contracts to the parent orchestrator prompt automatically.

Rebuild symlinks and use it:

```bash
dotpi sync
cd ~/projects/my-api
docs-mas "Write API reference docs for all endpoints in src/routes/"
```

## 9. Sharing Auth Across Agents

Each agent has its own config root, including API authentication. After you authenticate in one agent, share it with others:

```bash
# Authenticate via the recon agent
recon
# (pi prompts for API key on first run, saves to agents/recon/auth.json)

# Share that auth with other agents
dotpi link-auth recon impl
dotpi link-auth recon blog
```

## 10. Check Your Setup

See what agent configs are available and whether their extensions are properly linked:

```bash
dotpi list
```

```
Multi-agent systems:
  deepresearch  (workspace, 4 subagents, 1 prompts, orchestrator linked: yes)

Standalone agents:
  ask  (in-situ, extensions: 1)
  web  (in-situ, extensions: 1)
```
