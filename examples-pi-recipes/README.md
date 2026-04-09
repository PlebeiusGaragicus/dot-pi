# pi-coder

Pi extension reference, adapted from [IndyDevDan's pi-vs-cc](https://github.com/indydevdan/pi-vs-cc) tutorial.

---

NOTE: use the below models.json that works with my PlebChat API. it belongs in `~/.pi/agent/models.json`

```json
{
  "providers": {
    "plebchat": {
      "baseUrl": "https://api.plebchat.me/",
      "api": "anthropic-messages",
      "apiKey": "...",
      "models": [
        {
          "id": "qwen/qwen3-coder-next",
          "name": "Qwen3 Coder Next",
          "input": ["text"]
        },
        {
          "id": "zai-org/glm-4.6v-flash",
          "name": "GLM-4.6V Flash (Vision)",
          "input": ["text", "image"]
        }
      ]
    }
  }
}
```

---

## Prerequisites

- **Bun** >= 1.3.2 -- [bun.sh](https://bun.sh)
- **just** -- `brew install just`
- **pi** -- [Pi Coding Agent](https://github.com/mariozechner/pi-coding-agent)

Some extensions parse YAML configs (agent-team, agent-chain). Install the dependency:

```bash
bun add yaml
```

---

## How `~/.pi/` and `.pi/` work together

Pi uses a two-level config hierarchy, like git's `~/.gitconfig` + `.git/config`:

- **`~/.pi/agent/`** -- global (user-level): your settings, models, keybindings, themes, extensions, skills
- **`.pi/`** (in any project dir) -- project-level: overrides/supplements global config

They merge at runtime, with project-level taking precedence. This means the `.pi/` directory in this repo provides project-specific agent personas, themes, team definitions, and damage-control rules that only activate when Pi runs from this directory. It does not conflict with your global `~/.pi/`.

---

## Global usage -- run recipes from any project

The justfile uses absolute paths internally (`justfile_directory()`), so recipes resolve correctly regardless of where you invoke them. One-time setup gives you the `fu` command system-wide.

### Setup

1. Add to `~/.zshrc`:

```bash
export PI_RECIPES="$HOME/Downloads/2026-project/pi-recipes"
```

2. The `fu` script lives in `~/.local/bin/` (already on PATH). It reads `$PI_RECIPES` and delegates to `just`:

```bash
#!/usr/bin/env bash
if [[ -z "$PI_RECIPES" ]]; then
    echo "fu: \$PI_RECIPES is not set. Add to ~/.zshrc:"
    echo '  export PI_RECIPES="$HOME/path/to/pi-recipes"'
    exit 1
fi
exec just --justfile "$PI_RECIPES/justfile" --working-directory "$PWD" "$@"
```

3. Reload your shell: `source ~/.zshrc`

### Usage

From any project directory:

```bash
fu                        # list all recipes
fu pi                     # plain Pi
fu ext-minimal            # minimal footer + theme cycler
fu ext-damage-control     # safety auditing + minimal
fu analyst                # data analyst persona
```

Pi runs in your current working directory, so project-local `.pi/` configs still apply. Extensions are loaded from `$PI_RECIPES/extensions/`.

### Alternative: alias instead of script

If you'd rather skip the script, add this single alias to `~/.zshrc`:

```bash
export PI_RECIPES="$HOME/Downloads/2026-project/pi-recipes"
alias fu='just --justfile "$PI_RECIPES/justfile" --working-directory "$PWD"'
```

---

## Extensions

### Orchestration (`extensions/orchestration/`)

Multi-agent delegation and pipeline extensions:

| Extension             | File                                                | Description                                                      |
| --------------------- | --------------------------------------------------- | ---------------------------------------------------------------- |
| **agent-chain**       | `extensions/orchestration/agent-chain.ts`           | Sequential pipeline: chains agents where each output feeds the next |
| **agent-team**        | `extensions/orchestration/agent-team.ts`            | Dispatcher orchestrator: delegates to specialist agents via grid dashboard |
| **pi-pi**             | `extensions/orchestration/pi-pi.ts`                 | Meta-agent that builds Pi agents using parallel expert research  |
| **subagent-widget**   | `extensions/orchestration/subagent-widget.ts`       | `/sub <task>` spawns background Pi subagents with live progress widgets |
| **control**           | `extensions/orchestration/control.ts`               | Inter-session communication via Unix domain sockets (JSON-RPC)  |
| **subagent**          | `extensions/subagent/`                              | Full subagent delegation: single, parallel, chain modes          |
| **plan-mode**         | `extensions/plan-mode/`                             | Read-only exploration with plan extraction and progress tracking |

### UI & Display (`extensions/ui/`)

Display, chrome, feedback, and rendering extensions:

| Extension             | File                                    | Description                                                      |
| --------------------- | --------------------------------------- | ---------------------------------------------------------------- |
| **minimal**           | `extensions/ui/minimal.ts`             | Compact footer: model name + 10-block context meter              |
| **pure-focus**        | `extensions/ui/pure-focus.ts`          | Removes footer and status line -- distraction-free mode          |
| **theme-cycler**      | `extensions/ui/theme-cycler.ts`        | Ctrl+X/Ctrl+Q and `/theme` to cycle custom themes               |
| **session-replay**    | `extensions/ui/session-replay.ts`      | Scrollable timeline overlay of session history                   |
| **tool-counter**      | `extensions/ui/tool-counter.ts`        | Rich two-line footer: model, context, tokens, cost, branch, tool tally |
| **tool-counter-widget** | `extensions/ui/tool-counter-widget.ts` | Live widget showing per-tool call counts above the editor       |
| **chart**             | `extensions/ui/chart.ts`               | Inline matplotlib chart rendering (iTerm2 / ANSI fallback)      |
| **notify**            | `extensions/ui/notify.ts`              | Desktop notifications when agent finishes (OSC 777/99/Windows)  |
| **titlebar-spinner**  | `extensions/ui/titlebar-spinner.ts`    | Braille spinner in terminal title while agent works             |
| **summarize**         | `extensions/ui/summarize.ts`           | `/summarize` -- LLM conversation summary in overlay UI          |
| **custom-footer**     | `extensions/ui/custom-footer.ts`       | Custom footer with git branch + token stats                     |
| **inline-bash**       | `extensions/ui/inline-bash.ts`         | Expand `!{command}` patterns in prompts before sending          |
| **context**           | `extensions/ui/context.ts`             | `/context` TUI showing extensions, skills, context usage, tokens/cost |
| **session-breakdown** | `extensions/ui/session-breakdown.ts`   | `/session-breakdown` analytics: calendar graph, model costs, 7/30/90d |
| **whimsical**         | `extensions/ui/whimsical.ts`           | Random fun "Thinking..." replacements ("Bribing the compiler...") |
| **files-browser**     | `extensions/ui/files-browser.ts`       | Full file browser with git status, fuzzy search, Quick Look, diff |
| **tools**             | `extensions/ui/tools.ts`               | `/tools` command to enable/disable tools interactively           |
| **question**          | `extensions/ui/question.ts`            | Single-question tool with custom UI options                      |
| **questionnaire**     | `extensions/ui/questionnaire.ts`       | Multi-question TUI with tab navigation                           |

### Workflow & Productivity (`extensions/workflow/`)

Session behavior, agent selection, and development environment extensions:

| Extension             | File                                          | Description                                                      |
| --------------------- | --------------------------------------------- | ---------------------------------------------------------------- |
| **cross-agent**       | `extensions/workflow/cross-agent.ts`          | Loads commands from `.claude/`, `.gemini/`, `.codex/` dirs into Pi |
| **purpose-gate**      | `extensions/workflow/purpose-gate.ts`         | Declare session intent on startup; blocks prompts until answered |
| **system-select**     | `extensions/workflow/system-select.ts`        | `/system` to switch agent personas from `.pi/agents/`            |
| **tilldone**          | `extensions/workflow/tilldone.ts`             | Task discipline -- define tasks before working, tracks completion |
| **uv**                | `extensions/workflow/uv.ts`                   | Redirect pip/poetry/python to `uv` equivalents                  |
| **preset**            | `extensions/workflow/preset.ts`               | Named presets for model, thinking, tools, and instructions       |
| **todo**              | `extensions/workflow/todo.ts`                 | Todo tool + `/todos` with branch-aware state persistence         |
| **handoff**           | `extensions/workflow/handoff.ts`              | Transfer context to a new focused session via LLM summary        |
| **trigger-compact**   | `extensions/workflow/trigger-compact.ts`      | Auto-trigger compaction at token threshold                       |
| **custom-compaction** | `extensions/workflow/custom-compaction.ts`    | Custom compaction with full LLM summarization                    |
| **claude-rules**      | `extensions/workflow/claude-rules.ts`         | Inject `.claude/rules/` into Pi system prompt                    |
| **review**            | `extensions/workflow/review.ts`               | `/review` multi-mode code review (PR, branch, uncommitted, loop-fix) |
| **loop**              | `extensions/workflow/loop.ts`                 | `/loop` iterative coding until tests pass or condition met       |
| **todos**             | `extensions/workflow/todos.ts`                | File-based todo manager with `todo` tool and `/todos` TUI       |
| **prompt-editor**     | `extensions/workflow/prompt-editor.ts`        | Mode system for model + thinking level combos, `/mode` command   |
| **answer**            | `extensions/workflow/answer.ts`               | `/answer` extracts questions from assistant, interactive Q&A TUI |

### Safety & Guardrails (`extensions/safety/`)

| Extension               | File                                        | Description                                                      |
| ----------------------- | ------------------------------------------- | ---------------------------------------------------------------- |
| **damage-control**      | `extensions/safety/damage-control.ts`       | YAML-rule safety auditing -- blocks dangerous bash patterns      |
| **permission-gate**     | `extensions/safety/permission-gate.ts`      | Confirms before dangerous bash commands (rm -rf, sudo, chmod 777) |
| **protected-paths**     | `extensions/safety/protected-paths.ts`      | Blocks write/edit to `.env`, `.git/`, `node_modules/`            |
| **dirty-repo-guard**    | `extensions/safety/dirty-repo-guard.ts`     | Prevents session changes with uncommitted git changes            |
| **confirm-destructive** | `extensions/safety/confirm-destructive.ts`  | Prompts before destructive session actions (clear, switch, fork) |
| **go-to-bed**           | `extensions/safety/go-to-bed.ts`            | Blocks tool calls during quiet hours (00:00-05:59) until confirmed |
| **sandbox**             | `extensions/safety/sandbox/`                | OS-level sandboxing for bash (filesystem + network restrictions) |

### Git Integration (`extensions/git/`)

| Extension               | File                                    | Description                                                      |
| ----------------------- | --------------------------------------- | ---------------------------------------------------------------- |
| **git-checkpoint**      | `extensions/git/git-checkpoint.ts`      | Git stash checkpoints at each turn; restore on fork              |
| **auto-commit-on-exit** | `extensions/git/auto-commit-on-exit.ts` | Auto-commits on exit using last assistant message                |

### Boilerplate Templates (`extensions/examples/boilerplate/`)

Minimal, well-structured starting points for building new extensions. These are teaching aids, not production extensions.

| Template              | File                                                    | Pattern Demonstrated                        |
| --------------------- | ------------------------------------------------------- | ------------------------------------------- |
| **hello**             | `extensions/examples/boilerplate/hello.ts`              | Minimal custom tool                         |
| **status-line**       | `extensions/examples/boilerplate/status-line.ts`        | Lifecycle hooks + status display            |
| **widget-placement**  | `extensions/examples/boilerplate/widget-placement.ts`   | Widget positioning (above/below editor)     |
| **model-status**      | `extensions/examples/boilerplate/model-status.ts`       | Event listener (model changes)              |
| **input-transform**   | `extensions/examples/boilerplate/input-transform.ts`    | Input interception/transformation           |
| **custom-header**     | `extensions/examples/boilerplate/custom-header.ts`      | Header customization                        |
| **event-bus**         | `extensions/examples/boilerplate/event-bus.ts`          | Inter-extension communication               |
| **session-name**      | `extensions/examples/boilerplate/session-name.ts`       | Session metadata                            |
| **bookmark**          | `extensions/examples/boilerplate/bookmark.ts`           | Session labeling for /tree navigation       |
| **pirate**            | `extensions/examples/boilerplate/pirate.ts`             | Dynamic system prompt modification          |
| **bash-spawn-hook**   | `extensions/examples/boilerplate/bash-spawn-hook.ts`    | Bash command/env customization              |

### Pattern Showcases (`extensions/examples/patterns/`)

Intermediate examples demonstrating specific extension API patterns. These are reference implementations to copy and adapt.

| Pattern               | File                                                         | Pattern Demonstrated                              |
| --------------------- | ------------------------------------------------------------ | ------------------------------------------------- |
| **tool-override**     | `extensions/examples/patterns/tool-override.ts`              | Override built-in tools with logging/access control|
| **built-in-renderer** | `extensions/examples/patterns/built-in-tool-renderer.ts`     | Custom rendering for built-in tools               |
| **truncated-tool**    | `extensions/examples/patterns/truncated-tool.ts`             | Output truncation with temp file fallback          |
| **message-renderer**  | `extensions/examples/patterns/message-renderer.ts`           | Custom message rendering with `registerMessageRenderer` |
| **send-user-message** | `extensions/examples/patterns/send-user-message.ts`          | Programmatic user messages with `deliverAs`        |
| **reload-runtime**    | `extensions/examples/patterns/reload-runtime.ts`             | Runtime reload via command and tool                |
| **timed-confirm**     | `extensions/examples/patterns/timed-confirm.ts`              | Auto-dismissing dialogs with timeout/AbortSignal   |
| **file-trigger**      | `extensions/examples/patterns/file-trigger.ts`               | File watching with `fs.watch()` to inject content  |
| **interactive-shell** | `extensions/examples/patterns/interactive-shell.ts`          | Running interactive terminal commands (vim, htop)  |

### Project-Scoped Examples (`extensions/project-scoped/`)

Extensions that demonstrate project-level workflows (git diffs, file tracking, etc.). Loaded explicitly via `-e`, not auto-loaded from `.pi/extensions/`:

| Extension               | File                                                    | Description                                          |
| ----------------------- | ------------------------------------------------------- | ---------------------------------------------------- |
| **tps**                 | `extensions/project-scoped/tps.ts`                      | Tokens-per-second throughput display                  |
| **redraws**             | `extensions/project-scoped/redraws.ts`                  | TUI redraw statistics via `/tui` command              |
| **prompt-url-widget**   | `extensions/project-scoped/prompt-url-widget.ts`        | GitHub PR/Issue URL metadata widget                   |
| **files**               | `extensions/project-scoped/files.ts`                    | File operations tracker with VS Code integration      |
| **diff**                | `extensions/project-scoped/diff.ts`                     | Git diff viewer with VS Code diff tool                |

### Custom Providers (`extensions/providers/`)

Reference implementations for integrating non-standard LLM backends:

| Provider              | Directory                                              | Description                              |
| --------------------- | ------------------------------------------------------ | ---------------------------------------- |
| **Anthropic**         | `extensions/providers/custom-provider-anthropic/`      | OAuth + custom streaming                 |
| **GitLab Duo**        | `extensions/providers/custom-provider-gitlab-duo/`     | GitLab Duo proxy                         |
| **Qwen CLI**          | `extensions/providers/custom-provider-qwen-cli/`       | Qwen with OAuth device flow              |

### Demos (`extensions/examples/demos/`)

Fun showcase extensions demonstrating TUI rendering and game loop capabilities. These stress-test the TUI library.

| Demo                  | File/Directory                                           | Description                                     |
| --------------------- | -------------------------------------------------------- | ----------------------------------------------- |
| **snake**             | `extensions/examples/demos/snake.ts`                     | Snake game overlay in the terminal               |
| **space-invaders**    | `extensions/examples/demos/space-invaders.ts`            | Space Invaders game overlay                      |
| **doom-overlay**      | `extensions/examples/demos/doom-overlay/`                | DOOM running in the terminal via WASM            |

---

## Skills (`.pi/skills/`)

Reusable tool-backed capabilities the agent can invoke. Each skill has a `SKILL.md` describing its purpose and usage, plus supporting scripts.

### Developer Tools

| Skill | Directory | Description |
| ----- | --------- | ----------- |
| **commit** | `.pi/skills/commit/` | Conventional Commits guidelines |
| **github** | `.pi/skills/github/` | GitHub CLI (`gh`) interaction guide |
| **mermaid** | `.pi/skills/mermaid/` | Mermaid diagram validation + ASCII preview |
| **update-changelog** | `.pi/skills/update-changelog/` | Changelog management from git history |
| **uv** | `.pi/skills/uv/` | Python package manager (`uv`) quick reference |
| **tmux** | `.pi/skills/tmux/` | Remote control tmux sessions |
| **sentry** | `.pi/skills/sentry/` | Sentry error tracking API (issues, events, logs) |

### Design & Frontend

| Skill | Directory | Description |
| ----- | --------- | ----------- |
| **frontend-design** | `.pi/skills/frontend-design/` | Guidelines for distinctive, production-ready interfaces |

### Content & Web

| Skill | Directory | Description |
| ----- | --------- | ----------- |
| **summarize** | `.pi/skills/summarize/` | Convert URLs/files to Markdown via `uvx markitdown` |
| **native-web-search** | `.pi/skills/native-web-search/` | Fast web search via LLM model |
| **web-browser** | `.pi/skills/web-browser/` | Chrome DevTools Protocol browser automation (12 scripts) |
| **bowser** | `.pi/skills/bowser.md` | Playwright-based browser automation |
| **pi-share** | `.pi/skills/pi-share/` | Load Pi session transcripts from GitHub Gists |

### Productivity & Mail

| Skill | Directory | Description |
| ----- | --------- | ----------- |
| **google-workspace** | `.pi/skills/google-workspace/` | Google Workspace APIs with OAuth |
| **apple-mail** | `.pi/skills/apple-mail/` | macOS Mail search, read, and attachment extraction |

### Reverse Engineering & 3D

| Skill | Directory | Description |
| ----- | --------- | ----------- |
| **ghidra** | `.pi/skills/ghidra/` | Headless Ghidra binary analysis (decompile, functions, strings) |
| **openscad** | `.pi/skills/openscad/` | 3D modeling: validate, preview, export STL |

---

## Usage

From this directory you can use `just` directly. From anywhere else, use `fu` (see setup above).

```bash
fu                          # list all recipes
fu pi                       # plain Pi
fu ext-minimal              # minimal footer + theme cycler
fu ext-damage-control       # safety auditing + minimal
fu ext-tilldone             # task discipline + theme cycler
fu analyst                  # data analyst persona
```

Run a single extension manually:

```bash
pi -e extensions/ui/minimal.ts
```

Stack multiple:

```bash
pi -e extensions/ui/minimal.ts -e extensions/ui/theme-cycler.ts
```

---

## Project structure

```
pi-recipes/
├── extensions/              # Pi extension source files (.ts)
│   ├── themeMap.ts          # Shared theme utility (imported by most extensions)
│   ├── orchestration/       # Multi-agent delegation & pipeline extensions
│   ├── ui/                  # Display, chrome, feedback, rendering extensions
│   ├── workflow/            # Session behavior, tools, agent selection extensions
│   ├── safety/              # Guardrail & safety extensions (incl. sandbox/)
│   ├── git/                 # Git integration extensions
│   ├── subagent/            # Full subagent delegation (directory-based)
│   ├── plan-mode/           # Read-only exploration mode (directory-based)
│   ├── project-scoped/      # Project-scoped extensions (tps, diff, files, etc.)
│   ├── providers/           # Custom LLM provider reference implementations
│   └── examples/            # Teaching aids and showcases (not production extensions)
│       ├── boilerplate/     # Minimal starting-point templates
│       ├── patterns/        # Intermediate API pattern showcases
│       └── demos/           # Fun demos (snake, space-invaders, doom)
├── examples/
│   ├── sdk/                 # 12 SDK usage examples (programmatic Pi agent)
│   └── skills/              # Example skills (API integration patterns)
├── .pi/
│   ├── agents/              # Agent definitions for team/chain extensions
│   │   ├── pi-pi/           # Expert agents for pi-pi meta-agent
│   │   ├── agent-chain.yaml
│   │   ├── teams.yaml
│   │   └── *.md             # Agent persona system prompts
│   ├── prompts/             # Prompt templates (pr, is, cl, make-release)
│   ├── skills/              # 16 skills (commit, github, ghidra, web-browser, etc.)
│   ├── themes/              # 12 custom color themes (.json)
│   ├── damage-control-rules.yaml
│   └── settings.json        # Pi workspace settings
├── docs/                    # 27 reference docs (extension API, skills, SDK, providers, etc.)
├── specs/                   # Feature specifications for extensions
├── scripts/                 # Utility scripts (cost.ts, session-transcripts.ts, etc.)
├── intercepted-commands/    # Python command redirectors for uv
├── AGENTS.md                # Agent rules and project conventions
└── justfile                 # just task definitions
```

---

## Documentation (`docs/`)

All reference docs are included locally. Key docs for developers:

### Core

- [EXTENSION-API.md](docs/EXTENSION-API.md) -- condensed extension API reference
- [skills.md](docs/skills.md) -- skills system (locations, structure, frontmatter)
- [prompt-templates.md](docs/prompt-templates.md) -- prompt template system
- [sdk.md](docs/sdk.md) -- TypeScript SDK reference
- [tui.md](docs/tui.md) -- TUI component library for extensions
- [packages.md](docs/packages.md) -- package creation and distribution

### Configuration

- [providers.md](docs/providers.md) -- API keys and provider setup
- [models.md](docs/models.md) -- custom models (Ollama, vLLM, etc.)
- [custom-provider.md](docs/custom-provider.md) -- custom provider development
- [settings.md](docs/settings.md) -- complete settings reference
- [keybindings.md](docs/keybindings.md) -- keybinding customization
- [THEME.md](docs/THEME.md) -- theme color conventions

### Internals

- [session.md](docs/session.md) -- session file format (JSONL, tree structure)
- [compaction.md](docs/compaction.md) -- compaction and branch summarization
- [rpc.md](docs/rpc.md) -- RPC protocol for external integrations
- [json.md](docs/json.md) -- JSON event stream mode

### Platform Setup

- [terminal-setup.md](docs/terminal-setup.md) -- terminal configuration
- [shell-aliases.md](docs/shell-aliases.md) -- shell alias configuration
- [windows.md](docs/windows.md) -- Windows-specific setup
- [termux.md](docs/termux.md) -- Android/Termux setup
- [tree.md](docs/tree.md) -- session tree navigation
- [development.md](docs/development.md) -- development environment setup

### Comparisons

- [COMPARISON.md](docs/COMPARISON.md) -- comparison with Claude Code
- [PI_VS_OPEN_CODE.md](docs/PI_VS_OPEN_CODE.md) -- comparison with OpenCode

### Upstream

- [Pi README](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/README.md) -- overview and getting started
- [extensions.md](https://github.com/badlogic/pi-mono/blob/main/packages/coding-agent/docs/extensions.md) -- full extension system docs (upstream)
