I want to consider @unix-abstraction.md philosophy and using `p` agents like unix utilities / "filters"

For example: let's say we transform our deepresearch agent team into a series of individual unix-like primitives. So, instead of calling an agent team I string together a series of individual agents with `|` wherein I may call:

```sh
# Sketch (see “what data moves across the pipe?” for a runnable layout with PIPE_RUN_DIR)
echo "…research question…" | p research | p collector | p summarize | p draft-report | p final-report -p "$(cat ~/templates/research-template.md)"
```

Similar to a unix utility each takes input (whether prompt, URL list, file list, etc.), makes side effects to tmp/artifact files, and generates output that the next stage can consume.

---

## what data moves across the pipe?

```sh
RUN_ID=$(date +%Y%m%d-%H%M%S)
export PIPE_RUN_DIR="${TMPDIR:-/tmp}/dot-pi-pipe-$RUN_ID"
mkdir -p "$PIPE_RUN_DIR" && cd "$PIPE_RUN_DIR" || exit 1

echo "daily creatine usage for healthy 30 year old male, health benefits and latest trends in health" \
  | p research \
  | p collector \
  | p summarize \
  | p draft-report \
  | p final-report "$(cat ~/templates/research-template.md)" > report.md
```

`p research`

**usage:** return a list of websites which are likely to assist with the provided research question

 - **input:** research question or topic
 - **side effects:** none
 - **output:** json list of sources, metadata, content snippet

`p collector`

**usage:** scrapes list of urls to tmp directory

 - **input:** list of urls to scrape
 - **side effects:** /tmp/$RUN_ID/*.md
 - **output:** file paths of each scraped file

`p summarize`

**usage:** produce a structured digest of everything the collector wrote—abstractive overview plus extractive quotes tied to source paths.

- **input:** stdin carrying either (a) a list of scraped file paths, or (b) a small JSON manifest `{ "files": [...], "topic": "..." }` emitted by the prior stage; the agent may also read those paths from disk in `PIPE_RUN_DIR` (see conventions below).
- **side effects:** `summaries/*.md` or a single `summary.md` under the run directory
- **output:** stdout text the next stage can treat as the canonical “research brief” (headings, bullet facts, quoted excerpts with citations)

`p draft-report`

**usage:** turn the brief into a long-form draft in a fixed house style (sections, transitions, open questions).

- **input:** stdin = summary / brief from `p summarize` (or a path pointer if the brief is only on disk)
- **side effects:** `draft.md` (and optionally `draft-meta.json` with outline or TODOs)
- **output:** stdout = short confirmation plus path hints, or the full draft on stdout if you standardize “body on stdout” for the next filter—pick one convention per pipeline and stick to it

`p final-report`

**usage:** apply a template (structure, required sections, tone) and emit the publishable artifact.

- **input:** stdin = draft text **or** a directive to read `draft.md` from cwd; template passed as `-p`, second heredoc, or `$(cat template.md)` so it is not fighting with the pipe for stdin (shell limitation: only one stdin stream).
- **side effects:** `report.md`, `report.pdf` (optional), assets/
- **output:** final report body on stdout **and/or** only on disk—again, choose one primary stream for chaining; most pipelines end here with `> report.md`

---

## shell-level contract (same spirit as `unix-abstraction.md`)

Each `p <name>` invocation in **batch** mode should behave like a filter:

| Stream | Role |
|--------|------|
| **stdin** | Task text, JSON, or file-list—whatever the previous stage promised |
| **stdout** | Machine- or human-readable **primary** handoff to the next `|` (final assistant message after JSON filtering in `p`) |
| **stderr** | Progress, tool chatter, warnings—must stay off stdout so pipes stay clean |
| **exit code** | `0` = success; non-zero should stop `&&` chains |
| **cwd / env** | Shared run directory so side effects are visible to later stages without passing megabytes on stdin |

Recommended env for multi-stage runs:

- `PIPE_RUN_DIR` – absolute path; every stage `cd`s here or treats it as the artifact root
- Optional: `PIPE_RUN_ID` – same idea as `$RUN_ID` for logging

Unix already solves “heavy data on disk, light data on the pipe”: `gcc` leaves `a.out` on disk; the pipe carries small text. Piped agents should do the same—**stdout carries summaries, pointers, and JSON manifests; blobs live under `PIPE_RUN_DIR`.**

---

## corrected “dream” one-liner (syntax)

The original sketch mixed a pipe with `p final-report < template`, which ties stdin to the file and **breaks** the pipe into `final-report`. Prefer one of:

```sh
# Template as argv / -p (template path or inlined)
... | p final-report -p "$(cat ~/templates/research-template.md)"

# Or process substitution if the shell supports it
... | p final-report -p "$(< ~/templates/research-template.md)"
```

If `final-report` must read the draft from stdin, pass the template via `-p` or a second flag, **not** via `< file` on the same command in a pipeline.

---

## stages vs. one team

| Piped `p` stages | Single team + subagent chain |
|------------------|------------------------------|
| Each stage is a separate pi process—slower, more tokens if context is re-explained | One orchestrator, shared session, `{previous}` as the pipe |
| Stages are reusable CLIs: swap `p summarize` (or another summarizer agent) and test in isolation | Tighter coupling; best when steps are not useful alone |
| Contract is **explicit** (stdout + files); easier to script in bash, `make`, CI | Contract is implicit in team prompts and tool use |

Use **pipes** when each primitive should stand alone like `grep`/`sort`. Use a **team** when you want one brain scheduling work and recovering from failures across steps.

---

## what we still need to agree on

1. **Manifest format** – e.g. JSON lines vs. one JSON object for URL lists, file paths, and scrape metadata so `collector` → `summarize` is unambiguous.
2. **Stdout vs. file for long artifacts** – for `draft-report` / `final-report`, either “body always in `draft.md` and stdout is one paragraph status” or “body on stdout for true filters”—mixing both without a rule will confuse scripts.
3. **Workspace** – today, workspace mode is tied to `workspace.conf` on the agent. For pipes, either run **in-situ** with a shared `PIPE_RUN_DIR` or evolve toward “caller picks output dir” as described in `unix-abstraction.md`.
4. **Idempotency** – whether re-running `p collector` overwrites `scraped/` or creates versioned subdirs (helps debugging failed pipelines).

---

## summary

The goal is **Lego bricks**: small agents with clear stdin/stdout contracts, artifacts in a known directory, and shell `|` as composition—same fractal as subagent chains, but at the **outer** boundary so bash, Make, and CI can orchestrate research (or any workflow) without bespoke glue functions. 