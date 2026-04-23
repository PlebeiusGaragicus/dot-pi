# Compiler vs. Interpreter: Two Paradigms for Agentic Programs

> How should a repeatable multi-step agent task be expressed? As a shell script that calls
> small agents (compiled), or as a natural-language program an orchestrator LLM runs
> (interpreted)? This doc argues they are the same kind of thing at different levels and
> lays out when each wins.

## The core distinction

Every multi-step agent workflow has two layers:

1. **Control flow** — sequence, branching (`if`), looping (`while`/`until`), parallelism (`xargs -P`), error handling.
2. **Work** — the actual model calls that search, scrape, summarize, judge, revise.

The paradigms differ in **where the control flow lives**:

| | Compiler paradigm | Interpreter paradigm |
|---|---|---|
| Control flow lives in | A shell script (or Make, Python, etc.) | A prompt (`team-prompt.md`) |
| Who executes it | `bash` / `sh` | The orchestrator LLM |
| When decisions happen | Write time, with a few runtime `judge` escape hatches | Every token, the LLM re-decides |
| Work happens in | `research`, `scrape`, `summarize`, `judge`, … | Subagent tool calls dispatched from the orchestrator |
| Determinism | High — same script, same branches | Low — same prompt, different trajectories |
| Inspectability | Read the script, `diff` it, unit-test it | Read the prompt + every session JSONL to reconstruct what happened |

**Both paradigms still use an LLM inside each step.** The compiler paradigm does not eliminate the model — it just removes the model from the *scheduling* role. `summarize` is still an LLM call; it just doesn't decide what runs next.

## What each paradigm looks like in this repo

### Interpreter: `teams/deepresearch/team-prompt.md`

The team prompt is already a program. It has sequence, parallel dispatch, and conditionals:

```42:91:teams/deepresearch/team-prompt.md
## Standard workflow

For every research request, follow this pipeline:

### Step 1: Scout (single)

Dispatch the scout with the user's research topic. It will search and return a list of sources.
...
### Step 2: Collector (parallel)

Parse the scout's source list. Dispatch one collector per URL in parallel.
...
- If the scout finds fewer than 3 sources, consider asking it to try different search terms before proceeding.
- If a collector fails on a URL (paywall, timeout), note it but continue with the remaining sources.
```

That "If scout finds fewer than 3 sources…" line is an `if` statement written in English and evaluated by an LLM every run. The orchestrator is a **natural language interpreter**.

### Compiler: a shell script over agent primitives

The same workflow, compiled to bash with `judge` as the semantic conditional:

```bash
#!/usr/bin/env bash
set -euo pipefail

topic="$1"
mkdir -p sources

sources=$(echo "$topic" | research)

if ! echo "$sources" | judge "at least 3 high-quality, non-redundant sources?"; then
  sources=$(echo "$topic — broaden scope, try synonyms" | research)
fi

echo "$sources" | scrape                    # parallelism handled inside scrape

ls sources/*.md | summarize > summary.md

cp summary.md draft.md
for attempt in 1 2 3; do
  judge "does draft.md conform to template.md?" \
    < <(paste draft.md template.md) && break
  revise draft.md template.md
done
```

Every branch and every bound is explicit. The LLM does not pick the order — it only does the work inside each agent call.

## The symmetry you noticed

> "We must construct our prompt very strictly, breaking it down into steps (functions) with inputs, outputs and intended side effects."

Yes — and when you do that rigorously, **the prompt starts to look like source code.** Named steps become function names. "What the subagent receives" becomes the parameter list. "What it returns" becomes the return value. `{previous}` in chain mode becomes a pipe. Frontmatter fields like `tools`, `model`, `skills` become the function's environment.

The interpreter paradigm at its best is a disciplined natural-language DSL. The compiler paradigm is the same DSL expressed in bash. One is not inherently more "agentic" than the other; they are two notations for the same computation.

## Context rot — the interpreter's Achilles heel

The interpreter has one structural weakness: **the orchestrator's context window grows monotonically.** Every scout result, every collector report, every intermediate message stays in the main session. By step 4 (editor), the orchestrator's context contains:

- The original user topic
- The full scout output (sources list)
- N collector summaries (one per URL)
- The writer's full draft
- Tool-call bookkeeping between each

This is **context rot**: the model's attention dilutes across irrelevant history, latency and cost climb per turn, and the quality of late-stage reasoning degrades precisely when it matters most (editing).

Mitigations the interpreter paradigm requires:

1. **Subagent-first orchestration.** The orchestrator must push every non-trivial task into a subagent (fresh context window, isolated pi process, returns only a summary). The existing `teams/deepresearch/team-prompt.md` already does this — the orchestrator reads `report.md` at the end but never the `sources/*.md` directly. That is the correct pattern.
2. **Artifact-based handoffs.** Subagents return short status text; real deliverables live on disk (`sources/`, `report.md`). The orchestrator carries pointers, not payloads. This matches `unix-abstraction.md`'s "output may be a side effect, not a stream."
3. **Explicit context hygiene.** The prompt must forbid the orchestrator from quoting subagent outputs into its own messages. It should only reference paths and summaries.
4. **Short-lived sessions.** If the workflow has natural chapter breaks, consider running the orchestrator in multiple separate sessions, each starting fresh from on-disk state — effectively hand-compiling chapter boundaries.

The compiler paradigm **does not have this problem by construction.** Each agent invocation is a fresh pi process with an empty context. The only "shared state" is stdout/stderr between pipes and the filesystem. Context rot is impossible because there is no accumulating context to rot.

## What "agentic if / while" actually means

The novel primitive in the compiler paradigm is `judge` — a filter whose meaningful output is its **exit code**, not its stdout. It is to LLMs what `test` is to shell: a predicate whose only job is to return true or false so the surrounding control flow can branch.

| Unix | Agentic equivalent |
|---|---|
| `grep -q PATTERN file` | `judge "does file contain PATTERN (semantically)?"` |
| `[ -f report.md ]` | (keep as-is — structural checks don't need an LLM) |
| `diff -q a b` | `judge "are a and b substantively equivalent?"` |
| `test $x -gt 3` | `judge "is the content long enough to be a full draft?"` |

With `judge` plus bash `if`, `while`, `until`, `&&`, `||`, you get the full control-flow vocabulary. You do **not** need a new "agentic scripting language" — shell already has every construct. You only need one new predicate primitive. That is the whole addition.

## Real tradeoffs

| Concern | Compiler wins | Interpreter wins |
|---|---|---|
| **Reproducibility** | Script is deterministic; `judge` is the only nondeterministic branch point | LLM retraces the prose differently each run |
| **Cost control** | N LLM calls visible in the script, capped loops | Orchestrator tokens scale with context rot |
| **Debuggability** | `set -x`, per-step logs, inspect `$sources` between pipes | Session JSONL + subagent JSONL reassembly |
| **Adaptability to novel failure modes** | Only handles branches you anticipated | Can improvise — notice the topic is malformed and reframe it |
| **Speed of iteration on the workflow** | Edit a shell script | Edit English, test by running |
| **Onboarding cost** | Reader needs bash literacy | Reader needs to read the prompt |
| **Parallelism** | Explicit (`xargs -P`, `&`, `wait`) | Orchestrator dispatches parallel subagents naturally |
| **Graceful degradation** | Fails hard on unanticipated states | Can muddle through and still produce output |
| **Auditability** | Git history of the script | Git history of the prompt + every session |

The inflection is **"have you run this enough times to know its shape?"**

- **No, still exploring:** interpreter. You want the LLM to improvise around failures because you don't yet know what the failure modes are.
- **Yes, it's a recurring job:** compiler. You've paid for the discovery; now compile it down to something cheap, fast, and reliable.

## The honest recommendation for dot-pi

Do not pick one paradigm. **They compose.**

```bash
# Top-level: a compiled script
topic="$1"
echo "$topic" | research | scrape

# Mid-level: call a team (interpreter) for the hard adaptive part
deepresearch-synth > report.md    # team: writer + editor collaborate freely

# Post-check: compiled again
judge "does report.md meet our quality bar?" < report.md || exit 1
```

This is not a compromise — it is the right architecture. Use the compiler paradigm for the parts you understand well (find sources, scrape URLs, check quality gates). Use the interpreter paradigm inside one step where adaptive judgment is the point (writing and editing prose collaboratively). Let bash be the outer loop.

Concretely for this repo:

1. **Build the agent primitives first.** `research`, `scrape`, `summarize`, `judge`, `revise`. These are standalone agents with strict stdin/stdout contracts (per `piped-agents.md`). They are useful on their own, not just as deepresearch parts.
2. **Keep `teams/deepresearch` as-is** for interactive, exploratory use. It is the interpreter version, and it is good at what it does.
3. **Add a `scripts/deepresearch.sh`** that wires the primitives into a compiled pipeline for batch / CI / scheduled use. Same workflow, different paradigm, different use cases.
4. **Write the team prompts defensively** against context rot: forbid quoting subagent output, mandate artifact pointers, keep the orchestrator's job strictly clerical (dispatch, read final file, summarize).

## Decision framework

Ask, for the specific workflow:

1. **Is the control flow stable?** If yes → compiler. If no → interpreter, but write the prompt as if it were code (named steps, explicit I/O, side effects declared).
2. **Does a step need adaptive judgment that can't be reduced to a `judge` predicate?** If yes → that step belongs inside an interpreter (a team or a single rich agent).
3. **Is cost or reproducibility a hard constraint?** If yes → compiler.
4. **Are you still discovering the workflow?** If yes → interpreter, and plan to compile it once it stabilizes.
5. **Will this run unattended (cron, CI, webhook)?** If yes → compiler. Interpreters need a human in the loop to catch drift.

## Summary

The compiler paradigm moves control flow out of the prompt and into bash. It requires one new primitive (`judge`) and buys you determinism, cost control, and freedom from context rot. The interpreter paradigm keeps control flow in the prompt and requires rigorous "prompt as code" discipline plus aggressive subagent delegation to survive context rot. Neither is universally right. Build the agent primitives, keep the teams, and let each workflow pick its layer — or mix both.
