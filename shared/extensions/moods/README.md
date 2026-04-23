# Moods Extension

Swap an agent's system prompt at runtime via `/mood`, backed by markdown files in the agent directory.

## Commands

- `/mood <name>` — replace the system prompt with the body of `<agentDir>/moods/<name>.md`.
- `/mood off` (also `none`, `clear`) — revert to the agent's default `SYSTEM.md`.
- `/mood` with no argument — interactive picker.

Active mood appears in the status footer (`mood: plato`) and persists in the session, so `--resume` restores it.

## Directory layout

```
<agentDir>/
└── moods/
    ├── talk.md
    ├── plato.md
    └── ...
```

The filename (without `.md`), case-insensitive, is the command argument. The file body is the full system prompt for that mood. YAML frontmatter is parsed but ignored — reserved for future fields.

If `moods/` is missing or has no readable `.md` files, the extension silently no-ops.

## Adoption

```bash
ln -sf ../../../shared/extensions/moods <agentDir>/extensions/moods
mkdir -p <agentDir>/moods
# add markdown files
```
