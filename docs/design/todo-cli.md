# Todo CLI (`todo`)

Design reference for the minimal **`todo`** shell utility. Implementation and full command table: [`core/utilities/todo/todo`](https://github.com/PlebeiusGaragicus/dot-pi/blob/main/core/utilities/todo/todo) and [`core/utilities/todo/README.md`](https://github.com/PlebeiusGaragicus/dot-pi/blob/main/core/utilities/todo/README.md). The canonical source in a checkout lives under **`core/utilities/todo/`** (not a top-level `utilities/` path).

## Purpose

- Provide a **small**, **local-first** task list as **`todo.jsonl`** (one JSON object per line).
- Output **markdown-shaped** lines (`- [ ]` / `- [x]` with numeric ids) so humans and agents can paste lines into notes, logs, or context without extra tooling.

## Non-goals

The utility does **not** aim to support: tags, priorities, projects, nesting, sync, accounts, reminders, collaboration, or a query language. Those belong in other tools; the CLI surface is intentionally narrow.

## Resolution

1. Starting at the current working directory, walk upward directory by directory looking for a file named **`todo.jsonl`**.
2. If none is found before the filesystem root, the active file is **`~/.todo/todo.jsonl`**. The `~/.todo` directory is created if needed; an empty file may be created when that path is first used.

**Invariant:** the active list is always whatever **`todo which`** prints (absolute path). Run `todo which` before mutating tasks when the working directory might not be the intended repo.

## Naming and safety

- **`todo del <id>`** removes a **single task** by id from the active file.
- **`todo rm`** deletes the **entire active** `todo.jsonl` (the same path as `todo which`). Destructive; use with care.

Commands that prompt on a TTY accept **`-y`** / **`--yes`** to skip prompts—required for scripts and agents (`todo file`, `todo rm`, `todo tidy`).

## Data model

Each line is one JSON object with:

| Field   | Meaning                                      |
|--------|-----------------------------------------------|
| `id`   | Non-negative integer; unique within the file |
| `text` | Task description (string)                    |
| `done` | Boolean                                        |

New tasks receive the next free id: **max existing id + 1**, or **`0`** if the file is empty. Hand-editing or corrupt lines are out of scope; prefer using the CLI and avoiding invalid JSONL.

## Install

With **`core/bin`** on `PATH` (same as dot-pi agent commands), run **`dotpi relink`** so `core/bin/todo` points at **`core/utilities/todo/todo`**, unless an agent directory is literally named `agents/todo` (that name reserves the `todo` bin entry for the dispatcher). Details: [`core/utilities/todo/README.md`](https://github.com/PlebeiusGaragicus/dot-pi/blob/main/core/utilities/todo/README.md).
