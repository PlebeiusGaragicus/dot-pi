# ask

Explain agent — helps you understand what's in your current working directory. Read-only: inspects files but doesn't modify them.

## Usage

```
ask                              # interactive session
ask "how does the auth work?"    # quick question about your codebase
echo "summarize this repo" | ask # pipe input (batch mode)
```

## Configuration

- `SYSTEM.md` — system prompt (read-only tools)
- `pi-args` — default CLI flags
