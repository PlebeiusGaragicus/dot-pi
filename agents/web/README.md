# web

Research agent — searches the open web and academic papers (arXiv) via Tavily. Cites sources.

## Usage

```
web                                     # interactive session
web "latest advances in RISC-V"         # quick research query
echo "compare Rust vs Zig" | web        # pipe input (batch mode)
```

## Configuration

- `SYSTEM.md` — system prompt
- `pi-args` — default CLI flags
