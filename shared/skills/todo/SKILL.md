---
name: todo
description: Use bash for the `todo` cli utility for task lists management
disable-model-invocation: true
---

# Todo CLI

Use Bash to call `todo`; with dot-pi’s `core/bin` on `PATH`, run `dotpi relink` so `todo` is symlinked there (see `core/utilities/todo/README.md`).

Before using other todo commands, run bare `todo` to see the built-in usage:

```bash
todo
```

Common commands:

- `todo which` shows the active `todo.jsonl`.
- `todo list`, `todo done`, and `todo all` list tasks.
- `todo new "task text"` adds a task.
- `todo edit <id> "new text"` edits a task; prefer inline text instead of editor mode.
- `todo finish <id>`, `todo unfinish <id>`, and `todo del <id>` update tasks.
- Use `todo file -y`, `todo rm -y`, and `todo tidy -y` when automating.
