# ask

Explain agent — helps you understand what's in your current working directory. Read-only: inspects files but doesn't modify them.

## Usage

```
ask                              # interactive session
ask - "how does the auth work?"  # prompt, then stay interactive
echo "summarize this repo" | ask -p # pipe input as print-mode prompt
```

## Configuration

- `SYSTEM.md` — system prompt (read-only tools)
- `pi-args` — default CLI flags
