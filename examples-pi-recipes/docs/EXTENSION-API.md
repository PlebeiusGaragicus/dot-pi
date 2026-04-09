# Pi Coding Agent Extension API Reference

Condensed API reference for building Pi extensions. See `extensions/examples/boilerplate/` for minimal working examples of each pattern.

## Extension Structure

Extensions are TypeScript modules that export a default factory function:

```typescript
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
  // Register tools, commands, shortcuts, event handlers, etc.
}
```

### Discovery

Extensions are loaded from:
- **Project-local**: `<cwd>/.pi/extensions/*.ts`
- **Global**: `~/.pi/agent/extensions/*.ts`
- **Subdirectories**: `extensions/*/index.ts` or directories with `package.json` containing `"pi.extensions"`
- **CLI**: `pi --extension path/to/ext.ts`

---

## Events & Hooks

### Session Events

| Event | Description | Can Cancel? |
|-------|-------------|-------------|
| `session_start` | Initial session load | No |
| `session_before_switch` | Before switching sessions | Yes (`{ cancel: true }`) |
| `session_switch` | After switching sessions | No |
| `session_before_fork` | Before forking a session | Yes (`{ cancel: true }`) |
| `session_fork` | After forking a session | No |
| `session_before_compact` | Before context compaction | Yes (can customize) |
| `session_compact` | After context compaction | No |
| `session_shutdown` | On process exit | No |
| `session_before_tree` | Before navigating in session tree | Yes |
| `session_tree` | After navigating in session tree | No |

### Agent Lifecycle Events

| Event | Description | Can Modify? |
|-------|-------------|-------------|
| `before_agent_start` | After user submits prompt, before agent loop | Yes (systemPrompt, message) |
| `agent_start` | Agent loop begins | No |
| `agent_end` | Agent loop ends with all new messages | No |
| `turn_start` | New turn begins (one LLM call + tool executions) | No |
| `turn_end` | Turn completes with assistant message and tool results | No |

### Message Events

| Event | Description |
|-------|-------------|
| `message_start` | Any message begins (user, assistant, toolResult) |
| `message_update` | Assistant only - streaming token-by-token |
| `message_end` | Message completes |

### Tool Events

| Event | Description | Can Modify? |
|-------|-------------|-------------|
| `tool_call` | Before a tool executes | Yes (`{ block: true, reason }`) |
| `tool_result` | After a tool executes | Yes (can modify result) |
| `tool_execution_start` | Tool begins executing | No |
| `tool_execution_update` | Tool streams progress | No |
| `tool_execution_end` | Tool finishes executing | No |

### Other Events

| Event | Description | Can Modify? |
|-------|-------------|-------------|
| `context` | Before each LLM call | Yes (can filter/modify messages) |
| `model_select` | When a new model is selected | No |
| `user_bash` | When user executes bash via `!` prefix | Yes (can override result) |
| `input` | When user input is received | Yes (transform, handle, continue) |
| `resources_discover` | After session_start, provide additional resource paths | Yes |

### Event Handler Signature

```typescript
pi.on("event_name", async (event, ctx: ExtensionContext) => {
  // Return undefined for no-op, or a modification object
});
```

---

## Extension API Methods (`pi`)

### Tool Registration

```typescript
pi.registerTool<TParams, TDetails>({
  name: string;
  label: string;
  description: string;
  parameters: TSchema;          // TypeBox schema
  execute(toolCallId, params, signal, onUpdate, ctx): Promise<ToolResult>;
  renderCall?(args, theme): Component;      // Optional custom rendering
  renderResult?(result, opts, theme): Component;
});
```

### Command Registration

```typescript
pi.registerCommand("name", {
  description?: string;
  getArgumentCompletions?: (prefix: string) => AutocompleteItem[] | null;
  handler: (args: string, ctx: ExtensionCommandContext) => Promise<void>;
});
```

### Shortcut Registration

```typescript
pi.registerShortcut(Key.ctrl("x"), {
  description?: string;
  handler: (ctx: ExtensionContext) => Promise<void> | void;
});
```

### Flag Registration

```typescript
pi.registerFlag("name", { description?: string; type: "boolean" | "string"; default?: any });
pi.getFlag("name"): boolean | string | undefined;
```

### Message Rendering

```typescript
pi.registerMessageRenderer<T>("customType", (message, { expanded }, theme) => Component);
```

### Provider Registration

```typescript
pi.registerProvider("name", config: ProviderConfig);
pi.unregisterProvider("name");
```

### Actions

```typescript
pi.sendMessage({ customType, content, display, details }, { triggerTurn?, deliverAs? });
pi.sendUserMessage(content: string | Content[], { deliverAs?: "steer" | "followUp" });
pi.appendEntry(customType: string, data?: any);
pi.exec(command: string, args: string[], options?): Promise<ExecResult>;
pi.setModel(model): Promise<boolean>;
pi.setActiveTools(toolNames: string[]);
pi.getActiveTools(): string[];
pi.getAllTools(): ToolInfo[];
pi.getCommands(): SlashCommandInfo[];
pi.setThinkingLevel(level: ThinkingLevel);
pi.getThinkingLevel(): ThinkingLevel;
pi.setSessionName(name: string);
pi.getSessionName(): string | undefined;
pi.setLabel(entryId: string, label: string | undefined);
```

### Event Bus

```typescript
pi.events.on("channel", (data) => { ... });
pi.events.emit("channel", data);
```

---

## Extension Context (`ctx`)

Available in event handlers and tool execution:

```typescript
interface ExtensionContext {
  ui: ExtensionUIContext;
  hasUI: boolean;
  cwd: string;
  sessionManager: ReadonlySessionManager;
  modelRegistry: ModelRegistry;
  model: Model | undefined;
  isIdle(): boolean;
  abort(): void;
  hasPendingMessages(): boolean;
  shutdown(): void;
  getContextUsage(): ContextUsage | undefined;
  compact(options?): void;
  getSystemPrompt(): string;
}
```

### Extension Command Context (additional methods in command handlers)

```typescript
interface ExtensionCommandContext extends ExtensionContext {
  waitForIdle(): Promise<void>;
  newSession(options?): Promise<{ cancelled: boolean }>;
  fork(entryId): Promise<{ cancelled: boolean }>;
  navigateTree(targetId, options?): Promise<{ cancelled: boolean }>;
  switchSession(sessionPath): Promise<{ cancelled: boolean }>;
  reload(): Promise<void>;
}
```

---

## UI Context API (`ctx.ui`)

### Dialogs

```typescript
ctx.ui.select(title, options, opts?): Promise<string | undefined>;
ctx.ui.confirm(title, message, opts?): Promise<boolean>;
ctx.ui.input(title, placeholder?, opts?): Promise<string | undefined>;
ctx.ui.editor(title, prefill?): Promise<string | undefined>;
// opts can include: { timeout?: number; signal?: AbortSignal }
```

### Notifications

```typescript
ctx.ui.notify(message, type?: "info" | "warning" | "error"): void;
```

### Status & Widgets

```typescript
ctx.ui.setStatus(key, text | undefined): void;
ctx.ui.setWidget(key, lines[] | undefined, options?): void;
ctx.ui.setWidget(key, componentFactory | undefined, options?): void;
// options: { placement?: "belowEditor" }
```

### Header & Footer

```typescript
ctx.ui.setHeader(factory | undefined): void;
ctx.ui.setFooter(factory | undefined): void;
// factory: (tui, theme, footerData?) => Component & { dispose?() }
```

### Custom UI

```typescript
ctx.ui.custom<T>(factory, options?): Promise<T>;
// factory: (tui, theme, keybindings, done) => Component
// options: { overlay?: boolean; overlayOptions?: OverlayOptions }
```

### Editor

```typescript
ctx.ui.setEditorText(text): void;
ctx.ui.getEditorText(): string;
ctx.ui.pasteToEditor(text): void;
ctx.ui.setEditorComponent(factory | undefined): void;
```

### Theme

```typescript
ctx.ui.theme: Theme;
ctx.ui.getAllThemes(): { name, path }[];
ctx.ui.getTheme(name): Theme | undefined;
ctx.ui.setTheme(name | Theme): { success, error? };
```

### Title & Tools Display

```typescript
ctx.ui.setTitle(title): void;
ctx.ui.setWorkingMessage(message?): void;
ctx.ui.getToolsExpanded(): boolean;
ctx.ui.setToolsExpanded(expanded): void;
ctx.ui.onTerminalInput(handler): () => void;  // returns unsubscribe
```

---

## Built-in Tools

| Tool | Description |
|------|-------------|
| `read` | Read file contents |
| `bash` | Execute shell commands |
| `edit` | Edit files with diff-based changes |
| `write` | Write/create files |
| `grep` | Search files with regex |
| `find` | Find files by name patterns |
| `ls` | List directory contents |

### Tool Sets

- `codingTools`: read, bash, edit, write
- `readOnlyTools`: read, grep, find, ls
- `allTools`: all 7 tools

### Creating Built-in Tools

```typescript
import { createReadTool, createBashTool, createEditTool, createWriteTool } from "@mariozechner/pi-coding-agent";

const bashTool = createBashTool(cwd, {
  spawnHook?: ({ command, cwd, env }) => ({ command, cwd, env })
});
```

---

## Skills System

Skills are markdown files with frontmatter:

```markdown
---
name: skill-name              # optional, defaults to parent dir
description: What this does    # required
disable-model-invocation: false  # optional
---

Skill instructions here...
```

**Locations**: `~/.pi/agent/skills/`, `.pi/skills/`, or via `resources_discover`

Skills are formatted in the system prompt as XML for LLM discovery:
```xml
<available_skills>
  <skill>
    <name>skill-name</name>
    <description>Skill description</description>
    <location>/path/to/skill.md</location>
  </skill>
</available_skills>
```

---

## Prompt Templates

Markdown files that expand when used with `/template-name`:

```markdown
---
description: Create a new component
---

Create a new React component called $1 in the $2 directory.
```

**Arguments**: `$1`, `$2`, `$@` (all args), `$ARGUMENTS`, `${@:N}`, `${@:N:L}`

**Locations**: `~/.pi/agent/prompts/`, `.pi/prompts/`, or via `resources_discover`

---

## Themes

JSON files defining color schemes:

```json
{
  "name": "my-theme",
  "colors": {
    "accent": "#80b4e6",
    "border": "#3a3a3a",
    "success": "#a6e3a1",
    "error": "#f38ba8",
    "warning": "#f9e2af",
    "text": "#cdd6f4",
    "dim": "#585b70",
    "muted": "#a6adc8"
  }
}
```

**Locations**: Built-in, `~/.pi/agent/themes/`, or via `resources_discover`

**Theme API**:
```typescript
theme.fg(colorName, text): string;  // Apply foreground color
theme.bg(colorName, text): string;  // Apply background color
theme.bold(text): string;
theme.strikethrough(text): string;
```

---

## Common Patterns

### Blocking Tool Calls

```typescript
pi.on("tool_call", async (event, ctx) => {
  if (shouldBlock(event)) {
    return { block: true, reason: "Blocked because..." };
  }
});
```

### Modifying System Prompt

```typescript
pi.on("before_agent_start", async (event) => {
  return { systemPrompt: event.systemPrompt + "\n\nExtra instructions..." };
});
```

### Reconstructing State from Session

```typescript
pi.on("session_start", async (_event, ctx) => {
  for (const entry of ctx.sessionManager.getBranch()) {
    if (entry.type === "message" && entry.message.role === "toolResult") {
      // Reconstruct state from tool results
    }
  }
});
```

### Persisting State

```typescript
pi.appendEntry("my-state", { key: "value" });

// Restore on session_start by scanning entries
const entries = ctx.sessionManager.getEntries();
const stateEntry = entries
  .filter(e => e.type === "custom" && e.customType === "my-state")
  .pop();
```

### Input Transformation

```typescript
pi.on("input", async (event, ctx) => {
  if (event.text.startsWith("@")) {
    return { action: "transform", text: `Modified: ${event.text}` };
  }
  if (event.text === "ping") {
    ctx.ui.notify("pong", "info");
    return { action: "handled" };  // Don't send to LLM
  }
  return { action: "continue" };  // Normal processing
});
```

### Custom Footer with footerData

```typescript
ctx.ui.setFooter((tui, theme, footerData) => {
  const unsub = footerData.onBranchChange(() => tui.requestRender());
  return {
    dispose: unsub,
    invalidate() {},
    render(width) {
      const branch = footerData.getGitBranch();
      return [theme.fg("dim", `branch: ${branch}`)];
    },
  };
});
```

---

## TUI Components

Available from `@mariozechner/pi-tui`:

| Component | Description |
|-----------|-------------|
| `Text` | Render styled text |
| `Container` | Layout container for child components |
| `Box` | Bordered box with padding |
| `Markdown` | Render markdown content |
| `SelectList` | Interactive selection list |
| `SettingsList` | Settings toggle list |
| `DynamicBorder` | Responsive border line |
| `Spacer` | Vertical spacing |
| `Editor` | Text input editor |

### Utility Functions

```typescript
import {
  truncateToWidth,
  visibleWidth,
  wrapTextWithAnsi,
  matchesKey,
  Key,
} from "@mariozechner/pi-tui";
```
