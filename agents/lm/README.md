# lm

General-purpose conversational LLM agent. Runs in-situ (your current directory).

## Usage

```
lm                     # interactive session
lm - "your question"   # prompt, then stay interactive
echo "question" | lm -p # pipe input as print-mode prompt
```

## Configuration

- `SYSTEM.md` — system prompt
- `pi-args` — default CLI flags
- `banner.txt` — startup branding
