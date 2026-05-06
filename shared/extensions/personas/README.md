# Personas Extension

Select named system-prompt overlays from an agent-local `personas/` directory.

## Commands And Flags

- `/persona <name>` selects `<agentDir>/personas/<name>.md` for future turns.
- `/persona` with no argument opens an interactive picker.
- `--persona <name>` selects a persona at process startup, including print-mode and subagent runs.

If `personas/helpful.md` exists, it is the default persona.

The slash command is not registered when `PI_IS_SUBAGENT=1`, but the CLI flag still works so orchestrators can select personas non-interactively.

## Directory Layout

```text
<agentDir>/
└── personas/
    ├── helpful.md
    ├── chat.md
    └── ...
```

The filename without `.md` is the persona name.

## Frontmatter

```yaml
---
description: Human-readable summary for the picker
mode: append # append | prepend | replace
tools: read,ls
skills: skills/humanizer
theme: synthwave
---
```

`mode` controls prompt composition:

- `append` preserves the base prompt and appends the persona block. This is the default.
- `prepend` puts the persona block before the base prompt.
- `replace` replaces the base prompt with the persona body.

Use `replace` for tiny chat-only agents whose base prompt exists only to suppress pi's default prompt. Use `append` for capability agents whose safety, tool, or task instructions must remain in force.

## Adoption

```bash
ln -sf ../../../shared/extensions/personas <agentDir>/extensions/personas
mkdir -p <agentDir>/personas
# add markdown files
```
