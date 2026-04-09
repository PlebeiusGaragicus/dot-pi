# How I Use Pi

Custom modes built on top of pi-recipes. Each section describes a use case, what it does, how it was built, and how to launch it.

---

## Chat Mode

**What it does:** Pure conversational agent with no tools. The model answers questions entirely from its parametric knowledge -- no file access, no shell, no code execution. Useful for quick questions, brainstorming, rubber-ducking, or any situation where you want a fast back-and-forth without the agent wandering into your filesystem.

**How to launch:**

```bash
just chat        # from the pi-recipes directory
fu chat          # from any directory (if PI_RECIPES is set)
```

**How it was built:**

- **Extension** (`extensions/workflow/chat.ts`): Calls `pi.setActiveTools([])` on session start to disable all 7 built-in tools. Injects a system prompt addition via `before_agent_start` telling the model it has no tools and should answer conversationally. Shows a `chat` status indicator in the status bar.
- **Stacked extension** (`extensions/ui/pure-focus.ts`): Strips the footer and status line entirely for a distraction-free chat UI.
- **Theme mapping** (`extensions/themeMap.ts`): Maps `"chat"` to the `nord` theme -- a cool blue-gray palette that is visually distinct from the warmer/neon themes used by other extensions. You know you're in chat mode the moment the UI loads.
- **Justfile recipe**: `just chat` runs `pi -e extensions/workflow/chat.ts -e extensions/ui/pure-focus.ts`.

**Key design decisions:**

- Tools are set to an empty array (`[]`), not just read-only. The model has zero tool access -- it cannot even read files. This keeps responses fast and focused on knowledge retrieval.
- The system prompt explicitly tells the model not to attempt tool use, preventing hallucinated tool calls that would fail.
- Skills still appear in Pi's startup listing because Pi discovers them from `.pi/skills/` regardless of tool availability. But the model cannot use them -- skills require the `read` tool to load and typically `bash` to execute their scripts. In chat mode, both are disabled, so skills are effectively inert.
- The `nord` theme was chosen because it is the only unassigned theme, and its muted blue-gray tones feel distinctly "conversational" compared to the high-contrast coding themes.
- `pure-focus` is stacked to remove the footer bar entirely, keeping the interface as minimal as possible -- just the conversation and the input editor.

---

## Analyst

**What it does:** Data analysis workspace with inline chart rendering. The agent explores data, writes Python scripts, generates matplotlib visualizations, and explains findings in plain language. Charts saved to `charts/` are displayed inline in the terminal automatically.

**How to launch:**

```bash
just analyst     # from the pi-recipes directory
fu analyst       # from any directory
```

**How it was built:**

- **Agent persona** (`.pi/agents/analyst.md`): A detailed system prompt defining the analyst's workflow (clarify, acquire, explore, analyze, visualize, explain, document). Specifies conventions for matplotlib (Agg backend, dark style, save to `charts/`, never call `plt.show()`). Has full tool access (`read,write,edit,bash,grep,find,ls`).
- **Stacked extensions**: The justfile recipe loads three extensions together:
  - `extensions/ui/chart.ts` -- inline chart rendering in the terminal
  - `extensions/workflow/uv.ts` -- redirects python/pip commands to `uv` equivalents
  - `extensions/ui/minimal.ts` -- compact footer with model name and context meter
- **CLI flag**: Uses `--append-system-prompt .pi/agents/analyst.md` to inject the analyst persona on top of Pi's default system prompt (not replacing it).

**Key design decisions:**

- Uses `--append-system-prompt` rather than creating a custom extension. The analyst doesn't need to modify tools or hook into events -- it only needs a system prompt and some companion extensions. This is the simplest approach when all you need is behavioral guidance.
- The `uv` extension ensures Python dependencies are managed cleanly without requiring a global install of matplotlib, pandas, etc.
- The workspace convention (`data/`, `charts/`, `scripts/`, `METHOD.md`) keeps analysis artifacts organized and reproducible.


The agent writes Python scripts, runs them via `uv`, saves charts to `charts/`, and narrates the findings after each visualization.

---

## Vision Switch (Stackable Extension)

**What it does:** Automatically swaps to a vision-capable model when the agent reads an image file, then restores the original model after the LLM processes the result. This lets a smart text-only model (e.g. Qwen3 Coder) drive the entire workflow while seamlessly delegating image understanding to a vision model (e.g. GLM-4.6V).

**When to use:** Any session where the agent might encounter screenshots or images -- particularly with the bowser skill (Playwright browser automation), which takes screenshots that the model needs to interpret.

**How to use:**

Stack it with any recipe by adding `-e extensions/workflow/vision-switch.ts`:

```bash
# Standalone
pi -e extensions/workflow/vision-switch.ts

# Or use the justfile recipe
just vision

# Stacked with other extensions
pi -e extensions/orchestration/agent-team.ts -e extensions/workflow/vision-switch.ts
```

**How it was built:**

- **Extension** (`extensions/workflow/vision-switch.ts`): Hooks into four events:
  1. `tool_call` -- when the `read` tool targets an image file (`.png`, `.jpg`, `.jpeg`, `.gif`, `.webp`), checks if the current model supports image input. If not, saves the current model, switches to the vision model via `pi.setModel()`, and notifies the user.
  2. `tool_result` -- strips image content blocks from the tool result (replacing them with a text placeholder) and saves the raw image data (base64) in a buffer. This prevents the API from rejecting the request.
  3. `context` -- fires before each LLM call. If there are buffered images, injects them as a **user message** (where all APIs accept image content) so the vision model can see the image.
  4. `turn_end` -- skips the first turn_end after switching (the vision model hasn't responded yet), then restores the original model on the second turn_end.
- **Justfile recipe**: `just vision` runs `pi -e extensions/workflow/vision-switch.ts -e extensions/ui/minimal.ts`.
- **Configuration**: The vision model is defined as a const at the top of the file (`VISION_MODEL = { provider: "plebchat", id: "zai-org/glm-4.6v-flash" }`). Edit this to point at a different vision model if needed.
- **Prerequisite**: The vision model must be registered in `~/.pi/agent/models.json` with `"input": ["text", "image"]` so Pi knows it accepts images.

**The LM Studio tool_result problem (and how we solved it):**

The naive approach -- just switch models and let the read tool return image data -- fails with LM Studio (and most OpenAI-compatible servers). The error:

```
Error: 400 "Only text tool_result blocks are supported when tool_result.content is an array."
```

This happens because LM Studio's Anthropic-compatible API does not support `ImageContent` blocks inside `tool_result` messages. The OpenAI Chat Completions API doesn't support them either (tool messages only have string content). This is a server limitation, not a Pi bug.

The solution uses three Pi extension events to move the image from where it can't go (tool results) to where it can (user messages):

1. **`tool_result`** strips the image from the tool result → no more 400 error
2. **`context`** injects the saved image as a user message → vision model sees the image
3. **`turn_end` timing** is critical: the first `turn_end` fires after tool execution but *before* the vision model processes the image. We skip it. The second `turn_end` fires after the vision model responds, and that's when we restore the original model.

This pattern -- `tool_result` stripping + `context` injection -- is reusable for any provider that doesn't support multimodal tool results. The `chart.ts` extension uses a simpler version of the same pattern (strip-only, no re-injection).

**Key design decisions:**

- Images are moved from tool results to user messages, not dropped. The `chart.ts` extension strips images and tells the model to describe charts from the data that generated them. Vision-switch re-injects the actual image data so the vision model can see it.
- Only swaps if the current model lacks image support. If you're already on a vision model, it's a no-op.
- The `context` event modification is ephemeral -- it only affects the messages sent to the API for that one LLM call. The session history retains the text-only tool result. This avoids bloating the session with duplicate image data.
- Restores the original model after the vision model's response turn, not at agent_end. This minimizes the time spent on the (potentially less capable) vision model.
- Designed as a stackable utility, not a standalone mode. Add it to whatever recipe you're running.

---

## Reference: How Skills Work

Skills are Pi's mechanism for on-demand capability loading. Understanding how they work clarifies why they appear at startup but may seem invisible to the model.

**Discovery vs. loading**: At startup, Pi scans `.pi/skills/` and extracts each skill's `name` and `description` from its YAML frontmatter. These short summaries are injected into the system prompt as XML so the model knows what's available. The full SKILL.md content is NOT loaded into context -- that would waste tokens on skills that may never be needed.

**On-demand activation**: When the model encounters a task that matches a skill's description, it is expected to use the `read` tool to load the full SKILL.md, then follow its instructions (typically running scripts via `bash`). This is progressive disclosure -- only pay for what you use.

**Using skills manually**: Type `/skill:name` in the prompt input to force-load a skill. This sends the full SKILL.md content as a user message, bypassing the model's judgment about whether to load it. This is useful when you know which skill you want.

**Why the model might say "I don't have skills"**: The model sees skill names/descriptions in its system prompt, but some models interpret this as metadata about the system rather than capabilities they possess. If the model has no tools (like in chat mode), it genuinely cannot use skills since they require `read` and usually `bash`. Even with tools enabled, some models need prompting: "use the commit skill" or `/skill:commit` to trigger loading.

**Skill location rules**: Skills can be a `SKILL.md` file inside a named subdirectory (`skills/commit/SKILL.md`) or a standalone `.md` file directly in the skills directory (`skills/bowser.md`). The `name` field in frontmatter must match the parent directory name. For standalone files, the parent is `skills/` itself, so a file named `bowser.md` with `name: bowser` will trigger a validation warning because "bowser" does not match "skills". Move it to `skills/bowser/SKILL.md` to fix this.
