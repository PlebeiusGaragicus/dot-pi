# Unix Abstraction for Agent Systems

> Design document: aligning dot-pi's agent architecture with Unix process conventions.

## The Unix Philosophy

The foundational idea from Bell Labs (Thompson, Ritchie, McIlroy, 1970s):

> Write programs that do one thing and do it well.
> Write programs to work together.
> Write programs to handle text streams, because that is a universal interface.

Every Unix utility is a **filter**: it reads a stream of text in, transforms it, and writes a stream of text out. The genius is in the *composition* — the pipe (`|`) connects one process's stdout to the next process's stdin, and the shell handles all the wiring.

## The Standard Process Contract

Every Unix process gets three file descriptors at birth:

| Stream | FD | Default | Purpose |
|--------|---:|---------|---------|
| stdin  |  0 | keyboard | Input |
| stdout |  1 | terminal | Output (results) |
| stderr |  2 | terminal | Output (errors/diagnostics) |

A well-behaved Unix tool:

1. Reads from stdin *or* files given as arguments
2. Writes results to stdout
3. Writes diagnostics to stderr
4. Returns 0 on success, non-zero on failure
5. Accepts flags and env vars to modify behavior
6. Is **composable** — its output can be piped into another tool

Composition operators the shell provides for free: `|` (pipe), `&&` (sequence on success), `||` (fallback on failure), `$()` (capture output), `>` (redirect to file), `xargs` (fan-out).

## The Isomorphism: Unix Processes ≅ Agent Invocations

A Unix process and an agent invocation are structurally the same thing:

| Unix Process | Agent Invocation | Purpose |
|---|---|---|
| **argv** (`grep -i pattern`) | flags, positional args (`pi -p "topic"`) | Control behavior, pass the task |
| **stdin** | piped input / interactive prompt | The data to process |
| **stdout** | The agent's output (report, answer) | The result |
| **stderr** | Diagnostics, progress, errors | Side-channel for humans |
| **exit code** (`$?`) | Success/failure status | Did it work? |
| **env vars** (`$LANG`, `$DEBUG`) | `$PI_CODING_AGENT_DIR`, model config | Ambient configuration |
| **cwd** | Working directory | Context the tool operates on |
| **files on disk** | Workspace artifacts | Side-effect outputs |

This isomorphism holds at *every level* of the agent stack.

## The Fractal: Processes All the Way Down

```
Shell pipeline          grep foo | sort | head
                            ↕
Single pi invocation    pi-deepresearch -p "creatine"
                            ↕
Subagent dispatch       subagent(agent: "scout", task: "...")
                            ↕
Tool call               bash("curl https://...")
```

Every layer shares the same shape:

| | Shell Process | pi Invocation | Subagent Call | Tool Call |
|---|---|---|---|---|
| **Input** | stdin + argv | `-p` + cwd | `task` string | `params` object |
| **Output** | stdout | report / stdout | return text | result text |
| **Side effects** | files written | workspace artifacts | files created/modified | files, network |
| **Diagnostics** | stderr | session JSONL | session JSONL | tool logs |
| **Status** | exit code | exit code | exit code | success/error |
| **Identity** | binary name | `PI_CODING_AGENT_DIR` | agent `.md` file | tool registration |
| **Config** | env vars, flags | env vars, model config | frontmatter fields | schema |

A "program" — at any scale — is anything that:

1. Accepts **input** (text — a task, a question, data)
2. Produces **output** (text — an answer, a report, structured data)
3. May cause **side effects** (files created, APIs called, code modified)
4. Returns a **status** (success/failure)
5. Emits **logs** (session traces, diagnostics)
6. Is configured by **environment** (model, tools, identity)

There is no categorical distinction between a tool call, a subagent dispatch, a pi invocation, and a shell pipeline. They are all the same thing at different scales.

## Interactive vs Non-Interactive (isatty)

Unix tools don't have two "modes" baked into their identity. They check `isatty(stdin)` and adapt:

| Unix | Agent Equivalent |
|---|---|
| `python` (tty attached) | `pi-deepresearch` — interactive session |
| `echo "x=1" \| python` (piped) | `echo "topic" \| pi-deepresearch` — batch mode |
| `python -c "print(1)"` (flag) | `pi-deepresearch -p "topic"` — one-shot |
| `python script.py` (file arg) | `pi-deepresearch < prompt.md` — file input |

The same binary, the same flags. The **input source** determines the mode — not a property of the program's identity.

pi already supports `-p` and `--mode json` for non-interactive use (the `agent-orchestrator` extension uses both internally). The gap is that the outer shell aliases don't expose this, and there's no convention for stdout-as-result.

## In-Situ vs Workspace (cwd and side effects)

Under this lens, the "in-situ vs workspace" distinction maps to something Unix already solved — it's just **where side effects land**:

- **In-situ** = the program writes side effects into the caller's cwd (like `sed -i`, `git commit`, `gcc -o main`)
- **Workspace** = the program writes side effects into an isolated directory (like `mktemp -d`, or build systems using `$BUILDDIR`)

Unix doesn't make this a property of the *binary*. It's a property of the *invocation*:

```bash
gcc -o main main.c                        # in-situ: output lands in cwd
cd /tmp/build && gcc -o main ~/main.c     # workspace: output is isolated
```

The same tool, the same flags, just a different cwd.

Currently in dot-pi, `workspace.conf` makes workspace mode a property of *who the agent is* rather than *how you invoke it*. This is like having two separate binaries `grep` and `grep-to-file` instead of just `grep > file`.

## What Already Works (Inner Boundary)

Inside a single pi invocation, the `agent-orchestrator` extension already implements the Unix process model. Each subagent call returns a `SingleResult`:

```typescript
{
    agent:     string       // which "binary" ran
    task:      string       // the input (argv)
    exitCode:  number       // 0 = success, non-zero = failure
    messages:  Message[]    // stdout (the conversation/output)
    stderr:    string       // stderr (diagnostics)
    usage:     UsageStats   // resource accounting
    model:     string       // configuration
}
```

Chain mode is a pipeline — `{previous}` is the pipe:

```typescript
for (step of chain) {
    task = step.task.replace(/\{previous\}/g, previousOutput);
    result = await runSingleAgent(...);
    previousOutput = getFinalOutput(result.messages);
}
```

Parallel mode is `xargs -P` — bounded concurrency over independent tasks:

```typescript
results = await mapWithConcurrencyLimit(tasks, MAX_CONCURRENCY, ...)
```

Session JSONL files serve as the log/trace for each subagent process, and the extension already routes all subagent sessions into a unified directory when available.

## What Doesn't Work (Outer Boundary)

The shell-level interface — the outer boundary — is where the model breaks down:

```
┌──────────────────────────────────────────────────────┐
│  Shell (outer boundary) — BROKEN                     │
│                                                       │
│  pi-deepresearch  ──(manually)──>  pi-retro          │
│  no stdin contract    no stdout    bespoke glue       │
│                                                       │
│  ┌────────────────────────────────────────────────┐  │
│  │  Subagent tool (inner boundary) — WORKS        │  │
│  │                                                 │  │
│  │  scout ─{previous}─> writer ─> editor          │  │
│  │  input: task string                             │  │
│  │  output: getFinalOutput(messages)               │  │
│  │  status: exitCode                               │  │
│  │  side effects: files in cwd                     │  │
│  │  logs: session JSONL                            │  │
│  └────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────┘
```

### 1. No uniform input contract

`run-retro` is the only function that feeds a prompt programmatically (`-p "$prompt" < /dev/null`). All other aliases rely on interactive typing. There is no standard way to say `echo "Research creatine" | pi-deepresearch` and get a report on stdout.

### 2. No capturable output

Agent results are written to files (`report.md`, `retrospective-report.md`) or displayed in a TUI — never to stdout. You can't pipe a deepresearch run into retro. The `run-retro` function is essentially a hand-wired pipe (`deepresearch | retro`), implemented as a bespoke shell function rather than natural composition.

### 3. No exit status discipline

None of the aliases check or propagate pi's exit code. `run-retro` runs in a subshell `(cd ... && pi ...)` so the exit code vanishes. There is no way for a calling script to know if the agent succeeded or failed.

### 4. Interactive vs non-interactive is implicit

`run-retro` achieves non-interactive mode via `< /dev/null` and `-p`. But there is no `--batch` flag convention. Whether an agent is interactive is an accident of how you invoke it, not a first-class concept.

### 5. Workspace is fused with identity

Whether an agent gets a workspace is determined by the presence of `workspace.conf` — a property of *who the agent is*, not *how it's invoked*.

## Multi-Agent Considerations

Multi-agent systems add dimensions that a simple stdin/stdout model must account for:

### Session files as logs

Every subagent process produces a session JSONL file — the equivalent of structured log output. These must be captured and preserved regardless of invocation mode. The unified `sessions/` directory already handles this inside workspace runs; the same convention should apply to in-situ runs.

### Intermediate artifacts must survive

When a collector agent fetches a webpage and saves it to `sources/`, that file is both a side effect and an input to the next pipeline stage (the writer). These intermediate artifacts are the equivalent of temp files in a build system — they need to persist for:
- Downstream agents in the same pipeline
- After-action analysis (retro)
- Debugging failed runs

### Output may be a side effect, not a stream

Not every agent's "result" is text on stdout. An impl worker's real output is the files it modified. A collector's real output is the source file it saved. This is analogous to `gcc` — its useful output is `a.out`, not what it prints to stdout.

The contract should accommodate both:
- **Stream output**: the final assistant message (text result, report content)
- **Side-effect output**: files created or modified in cwd

Both are valid "outputs." The convention should be: stdout carries the *summary or result text*, side effects carry the *artifacts*. Just like `gcc` prints warnings to stderr and writes the binary to disk.

### Subagents are function calls

Inside a MAS, the orchestrator dispatching a subagent is structurally identical to a program calling a function:

- The `task` string is the function argument
- The returned text is the return value
- Files written are side effects
- The `exitCode` is the error status
- Session JSONL is the trace log

The `{previous}` placeholder in chain mode is literally argument passing — piping one function's return value into the next function's argument.

## Three Orthogonal Axes

The current design tangles three independent concerns:

| Axis | What decides it now | What should decide it |
|---|---|---|
| **Interactive vs batch** | Accident of invocation | `isatty(stdin)` + `-p` flag — the **invocation** decides |
| **In-situ vs workspace** | `workspace.conf` (agent identity) | `--workspace` / `--output-dir` flag — the **caller** decides |
| **Agent identity** | Which alias you call | Which command you call — the **command** decides |

These should be fully orthogonal. Any agent should be invocable interactively or in batch mode, in-situ or in a workspace, without changing its configuration.

## Target Design

### What Unix-aligned invocations look like

```bash
# Non-interactive, piped composition:
echo "creatine cognitive effects" | pi-deepresearch > report.md

# Chained agents (the real pipe dream):
echo "creatine cognitive effects" | pi-deepresearch | pi-retro > retro.md

# Batch mode with explicit input:
pi-deepresearch -p "creatine cognitive effects" --output report.md

# Interactive mode (default when stdin is a TTY):
pi-deepresearch   # drops into interactive chat, like python with no args

# Workspace is a flag, not an identity:
pi-deepresearch --workspace              # fresh dated dir
pi-deepresearch --workspace ./mydir      # specific output dir
pi-deepresearch                          # in-situ (default)

# Exit codes are meaningful:
pi-deepresearch -p "topic" && echo "Success" || echo "Failed"

# Env vars for ambient config:
PI_MODEL=haiku pi-deepresearch -p "quick question"
```

### The universal contract

Every agent invocation — whether a shell alias, a pi process, a subagent dispatch, or a tool call — follows the same contract:

```
(input, env, cwd) → (output, side-effects, status, logs)
```

| Component | Mechanism |
|---|---|
| **input** | stdin (piped text), `-p` flag (inline), or interactive TTY |
| **env** | `PI_CODING_AGENT_DIR`, `PI_MODEL`, and other env vars |
| **cwd** | The working directory (determines context and default side-effect location) |
| **output** | stdout (the result text — final assistant message or report content) |
| **side-effects** | Files created/modified in cwd or `--output-dir` |
| **status** | Exit code: 0 = success, non-zero = failure (propagated through aliases) |
| **logs** | Session JSONL in `sessions/` (structured trace of the entire run) |

### What needs to change

**1. Every pi invocation must have a capturable output.**
When running non-interactively, the final assistant message goes to stdout. `--mode json` already exists for subagent use; a simpler text-only mode should exist for shell composition. Session JSONL stays as the log (stderr-equivalent).

**2. Workspace is an invocation flag, not an identity.**
`workspace.conf` becomes a *default hint* — the alias uses it as the default behavior, but `--workspace`, `--in-situ`, and `--output-dir <path>` flags override. Any agent can run either way.

**3. Exit codes must propagate.**
The subshell wrappers in `dispatch-agent` must capture and return pi's exit code. The `agent-orchestrator` extension already tracks `exitCode` per agent — this needs to bubble up to the shell level.

Once these three properties hold, the entire system — from tool calls inside agents, through subagent dispatches, up to shell-level composition — speaks the same protocol. The shell's existing `|`, `&&`, `$()`, `>`, and `xargs` operators handle all the wiring. No more bespoke glue functions.

## Summary

> Don't build a cathedral. Build a box of Lego bricks and a way to snap them together.

The pipe is the snap. The contract is the brick shape. Every agent, at every level, should be the same kind of brick.
