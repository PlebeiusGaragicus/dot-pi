# Writing Extensions

Extensions are TypeScript modules that add custom behavior to pi. They can hook into the agent lifecycle, register new tools, and render custom TUI elements.

Source: `shared/extensions/` (shared) or `agents/<name>/extensions/` (per-agent)

## Extension Structure

An extension is either:

- A **single file**: `extensions/my-extension.ts`
- A **directory** with an entry point: `extensions/my-extension/index.ts` (can import sibling modules)

pi auto-discovers extensions from `<PI_CODING_AGENT_DIR>/extensions/` on startup.

## Minimal Extension

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
    // Add hooks and tools here
}
```

The default export receives an `ExtensionAPI` instance with two capabilities:

1. **`pi.on(event, handler)`** — register lifecycle hooks
2. **`pi.registerTool({ ... })`** — register tools the LLM can invoke

## Lifecycle Hooks

### `before_agent_start`

Fires before the agent processes a user message. Use it to modify the system prompt.

```typescript
pi.on("before_agent_start", async (event) => {
    return { systemPrompt: event.systemPrompt + "\n\nExtra instructions here." };
});
```

**Parameters:**

- `event.systemPrompt` — the current system prompt (string)

**Return value:** `{ systemPrompt: string }` to override, or `undefined` to leave unchanged.

**Note:** This hook does **not** receive `ctx`. For user interaction at startup, write to stdout in the extension body instead (see the [twenty-questions example](#example-twenty-questions)).

### `session_start`

Fires when pi's interactive session initializes. Receives `ctx` with full UI access. Use it for startup customization like setting headers, themes, or widgets.

```typescript
pi.on("session_start", async (_event, ctx) => {
    if (!ctx.hasUI) return;
    ctx.ui.setHeader((_tui, theme) => {
        const title = theme.bold(theme.fg("accent", "My Agent"));
        return new Text(title, 1, 1);
    });
});
```

**Parameters:**

- `event.reason` — why the session started (`"startup"`, `"reload"`, `"new"`, `"resume"`, `"fork"`)
- `ctx.ui.setHeader(factory)` — replace the startup header with a custom component
- `ctx.ui.setTheme(name)` — set the active theme
- `ctx.ui.notify(message, type)` — show a notification

### `agent_end`

Fires after the agent finishes processing (all tool calls complete, final message sent).

```typescript
pi.on("agent_end", async (event, ctx) => {
    ctx.ui.notify("Done", "Agent finished processing");
});
```

**Parameters:**

- `event.messages` — array of `Message` objects from the conversation
- `ctx.cwd` — current working directory
- `ctx.hasUI` — whether a TUI is available
- `ctx.ui.confirm(title, message)` — show a confirmation dialog (returns `Promise<boolean>`)
- `ctx.ui.notify(title, message)` — show a notification

## Registering Tools

Tools are functions the LLM can invoke during a conversation. Parameters are defined with [Typebox](https://github.com/sinclairzx81/typebox) schemas.

```typescript
import { Type } from "@sinclair/typebox";

pi.registerTool({
    name: "greet",
    label: "Greet",
    description: "Generate a greeting for a person",
    parameters: Type.Object({
        name: Type.String({ description: "Name of the person to greet" }),
        style: Type.Optional(Type.String({ description: "Greeting style: formal or casual" })),
    }),

    async execute(toolCallId, params, signal, onUpdate, ctx) {
        const greeting = params.style === "formal"
            ? `Good day, ${params.name}.`
            : `Hey ${params.name}!`;

        return {
            content: [{ type: "text", text: greeting }],
        };
    },
});
```

### Execute Function Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `toolCallId` | `string` | Unique ID for this tool invocation |
| `params` | `object` | Validated parameters matching your Typebox schema |
| `signal` | `AbortSignal` | Fires on user abort (Ctrl+C) |
| `onUpdate` | `(partial) => void` | Callback for streaming partial results |
| `ctx` | `object` | Context: `cwd`, `hasUI`, `ui.confirm()`, `ui.notify()` |

### Return Value

Return an `AgentToolResult`-shaped object:

```typescript
return {
    content: [{ type: "text", text: "result text" }],
    details: optionalStructuredData,  // passed to renderResult
    isError: false,                   // set true to signal failure
};
```

### Streaming Updates

Use `onUpdate` to stream partial results while the tool runs:

```typescript
async execute(toolCallId, params, signal, onUpdate, ctx) {
    onUpdate({
        content: [{ type: "text", text: "Step 1 of 3..." }],
        details: { progress: 1 },
    });

    // ... do work ...

    return { content: [{ type: "text", text: "Done!" }] };
},
```

### Typebox Parameter Patterns

```typescript
import { Type } from "@sinclair/typebox";
import { StringEnum } from "@mariozechner/pi-ai";

// Required string
Type.String({ description: "..." })

// Optional field
Type.Optional(Type.String({ description: "..." }))

// String enum
StringEnum(["option1", "option2"] as const, { description: "..." })

// Array of objects
Type.Array(Type.Object({
    name: Type.String({ description: "..." }),
    value: Type.String({ description: "..." }),
}))

// Boolean with default
Type.Optional(Type.Boolean({ description: "...", default: true }))
```

## TUI Rendering

Extensions can customize how tool calls and results appear in the terminal.

### `renderCall`

Renders the tool invocation (shown while the tool runs):

```typescript
renderCall(args, theme, context) {
    const text = theme.fg("toolTitle", theme.bold("greet "))
        + theme.fg("accent", args.name);
    return new Text(text, 0, 0);
},
```

### `renderResult`

Renders the tool result (shown after completion):

```typescript
renderResult(result, { expanded }, theme, context) {
    const container = new Container();

    container.addChild(new Text(
        theme.fg("success", "✓ ") + theme.fg("toolTitle", "Greeting sent"),
        0, 0
    ));

    if (expanded) {
        const mdTheme = getMarkdownTheme();
        container.addChild(new Spacer(1));
        container.addChild(new Markdown(result.content[0].text, 0, 0, mdTheme));
    }

    return container;
},
```

### TUI Components

| Component | Usage |
|-----------|-------|
| `new Text(content, x, y)` | Styled text line |
| `new Container()` | Layout container, use `.addChild(...)` |
| `new Markdown(content, x, y, theme)` | Rendered markdown block |
| `new Spacer(lines)` | Vertical spacing |

### Theme Colors

Use `theme.fg(colorName, text)` with these color names:

| Color | Purpose |
|-------|---------|
| `"accent"` | Highlighted content (file paths, agent names) |
| `"muted"` | De-emphasized text (labels, separators) |
| `"dim"` | Very subtle text (previews, counts) |
| `"error"` | Error indicators |
| `"success"` | Success indicators |
| `"warning"` | Warnings, team labels |
| `"toolTitle"` | Tool name in headers |
| `"toolOutput"` | Tool output content |

## Available Imports

```typescript
// Core extension API
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

// Utilities
import {
    getAgentDir,          // Resolved PI_CODING_AGENT_DIR path
    getMarkdownTheme,     // Theme object for Markdown TUI component
    withFileMutationQueue, // Serialize file writes
    parseFrontmatter,     // Parse YAML frontmatter from markdown
} from "@mariozechner/pi-coding-agent";

// TUI components
import { Container, Markdown, Spacer, Text } from "@mariozechner/pi-tui";

// Type system for tool parameters
import { Type } from "@sinclair/typebox";
import { StringEnum } from "@mariozechner/pi-ai";

// Message types
import type { AgentToolResult } from "@mariozechner/pi-agent-core";
import type { Message } from "@mariozechner/pi-ai";
```

## Examples

### Example: Twenty Questions

A standalone agent extension that shows a welcome overlay at load time and injects game rules via `before_agent_start`. Demonstrates writing to stdout at extension load and system prompt injection.

Source: `agents/twenty-questions/extensions/twenty-questions/index.ts`

Key patterns:

- Writes an ANSI-styled box to stdout in the extension body (runs before user input)
- Defines game rules as an inline string constant
- Uses `before_agent_start` purely for system prompt injection (no file I/O needed)

### Example: Run Finish Notify

A shared extension that hooks `agent_end` to send desktop notifications when the agent finishes. Demonstrates the `agent_end` hook with platform detection.

Source: `shared/extensions/run-finish-notify.ts`

Key patterns:

- Uses `ctx.ui.notify()` for in-app notification
- Detects platform (`process.platform`) for native notifications (macOS AppleScript, Linux notify-send, Windows PowerShell)
- Falls back to terminal escape codes (OSC 777 for most terminals, OSC 99 for Kitty)
- Checks `process.stdout.isTTY` to skip when not in a terminal

### Example: Subagent Teams

The most complex extension in the repo — registers a `subagent` tool with three execution modes, TUI rendering, and team-based agent discovery.

Source: `shared/extensions/subagent-teams/index.ts` (+ `agents.ts`)

Key patterns:

- Multi-file extension using a directory with `index.ts` entry point and `agents.ts` helper
- Full Typebox parameter schema with nested objects and enums
- Spawns child pi processes via `node:child_process` with `PI_IS_SUBAGENT=1` in their env
- Streams partial results via `onUpdate` callback
- Complex `renderCall` and `renderResult` with collapsed/expanded views
- Reads `team-prompt.md` via `before_agent_start` hook for orchestrator prompt injection (gated on `!process.env.PI_IS_SUBAGENT` so subagents don't receive it)
