# web

Research agent — searches the open web and academic papers (arXiv) via Tavily. Cites sources.

## Usage

```
web                                     # interactive session
web - "latest advances in RISC-V"       # prompt, then stay interactive
echo "compare Rust vs Zig" | web -p     # pipe input as print-mode prompt
```

## Configuration

- `SYSTEM.md` — system prompt
- `pi-args` — default CLI flags
