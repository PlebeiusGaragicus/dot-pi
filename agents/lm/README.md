# lm

General-purpose conversational LLM agent. Runs in-situ (your current directory).

## Usage

```
lm                     # interactive session
lm "your question"     # quick prompt
echo "question" | lm   # pipe input (batch mode)
```

## Configuration

- `SYSTEM.md` — system prompt
- `pi-args` — default CLI flags
- `banner.txt` — startup branding
