# Method Compare: Agent Directories vs Runtime Profiles

This note compares dot-pi's current agent-directory method with a possible runtime
profile method inspired by plan mode.

The question is whether the meaningful behavior in dot-pi's agent folders could
be reduced to a single extension loaded by vanilla `pi`. In that model, the user
would start `pi`, then choose an agent profile through a slash command or startup
flag. The profile extension would modify prompt, tools, skills, prompt templates,
theme, model, and orchestration behavior at runtime.

## Current Method: Config Roots

dot-pi currently treats each `agents/<name>/` directory as a complete
`PI_CODING_AGENT_DIR` root. The shell launcher chooses that root before pi starts.
Once pi starts, it discovers configuration from that directory:

- `SYSTEM.md` and `APPEND_SYSTEM.md` for base prompt behavior.
- `pi-args` for default CLI flags such as tools, model, thinking, skills, prompt
  templates, and context-file behavior.
- `extensions/` for loaded TypeScript extensions.
- `skills/` for native skill discovery.
- `prompts/` for native slash prompt templates.
- `agents/` for MAS subagent config roots.
- `models.json`, `auth.json`, and `settings.json` for provider, credential, and
  runtime settings.
- `sessions/` or a launcher-supplied `--session-dir` for session storage.
- `bootstrap.sh` for pre-launch environment setup and workspace behavior.

The main benefit is hard isolation. Each agent can have a different loaded
extension set, skill set, prompt set, session directory, launch cwd, and default
CLI argument list.

The cost is filesystem and launcher complexity. A small standalone agent may need
many files and symlinks just to express "use this prompt, these tools, this model,
and this theme."

## Alternative Method: Runtime Profiles

The proposed method is a universal extension loaded by vanilla pi, likely from
`~/.pi/agent/extensions/agent-profiles` or a similar default config root.

The user experience could look like:

```text
pi
/profile writer
```

or, if pi flags and extension flags make it convenient:

```text
pi --profile writer
```

The extension would read profile definitions from a registry, for example:

```text
profiles/
  writer.md
  browser.md
  coder.md
  deepresearch.md
```

or:

```text
agent-profiles.json
```

Each profile would define behavior that is currently spread across agent folders:

- Prompt replacement or prompt append.
- Active tool allowlist.
- Model selection.
- Theme selection.
- Skills as injected prompt material.
- Prompt templates as extension commands.
- Custom tools enabled for that profile.
- Subagent definitions and routing instructions.
- Status labels, banners, timers, notifications, and other UI behavior.

This matches plan mode's shape. Plan mode does not restart pi. It changes the
running process by toggling tools, injecting hidden context, adding commands,
tracking state, and restoring state on session start.

## Behavior Mapping

### Prompt

Runtime profile support is strong here.

An extension can use `before_agent_start` to replace or append to the active
system prompt. This can emulate `SYSTEM.md`, `APPEND_SYSTEM.md`, and the body of
`AGENT.md`.

Important difference: native `SYSTEM.md` is applied during pi's normal startup
configuration flow. A profile extension applies its changes only after the
extension has loaded and selected a profile. This is enough for most prompt
behavior, but it means the active profile must be known before the next model
turn starts.

### Tools

Runtime profile support is strong for active tool selection.

An extension can call `pi.setActiveTools(...)`, as plan mode and mood/profile
style extensions already do. This can emulate `--tools`, `--no-tools`, and much
of an agent-specific tool policy.

Important difference: all extensions that register tools must already be loaded.
An extension can hide or reveal tools, but it cannot load an entirely different
`extensions/` directory for the current process after startup.

### Model

Runtime profile support is good if providers are already known.

An extension can select a model through the model registry. This can emulate a
profile-level `--model` or `.model` override when the provider and model exist in
the loaded `models.json`.

Important difference: provider discovery is startup configuration. A profile
cannot reliably introduce a new provider at runtime if pi did not load that
provider from `models.json` on startup.

### Theme And UI

Runtime profile support is strong.

Extensions can set themes, titles, status widgets, headers, notifications, and
other TUI behavior during `session_start` and other lifecycle hooks. This can
replace much of the current banner, startup branding, timer, mood, and theme
customization layer.

### Skills

Runtime profile support is possible, but not equivalent.

The current method uses native `skills/` discovery from the active
`PI_CODING_AGENT_DIR`. A profile extension could read skill markdown files and
inject their content into the system prompt or hidden context.

That is likely good enough for many skills because a skill is mostly instruction
text. It is not exactly the same as native pi skill discovery, especially if pi
has special handling for skill metadata, skill selection, or skill display.

Profile-based skills would also change the mental model: skills become profile
prompt material rather than config-root resources.

### Prompt Templates

Runtime profile support is possible with a UX change.

Native prompt templates live in `prompts/` and are invoked as slash templates.
A profile extension could register commands such as `/research`, `/draft`, or
`/profile-template research`, then expand profile-specific template text into a
user message.

This is not identical to pi's native prompt-template discovery unless the
extension API exposes dynamic prompt-template registration. It can still provide
the same user-facing workflows if the command names are acceptable.

### Subagents And MAS

Runtime profile support is possible, but the isolation story changes.

The current MAS approach uses `agent-orchestrator` to discover subagent config
directories and spawn child pi processes with each subagent's own
`PI_CODING_AGENT_DIR`.

A profile extension could still register a `subagent` tool. It could also read
subagent profiles from a registry and spawn child pi processes. There are two
ways to do that:

1. Spawn child pi with the same universal config root and pass a subagent profile
   selection mechanism.
2. Generate or point to temporary/minimal config roots for subagents.

The first option keeps the extension-only ideal but weakens hard isolation. The
second option reintroduces config roots, just generated or hidden.

### Sessions

Runtime profile support is partial.

An extension can persist profile state into the current session. Plan mode does
this with `pi.appendEntry(...)` and restores state on `session_start`.

However, choosing the session directory is a launch-time concern. The launcher
currently passes `--session-dir` for workspace agents and resume flows. A running
extension cannot fully move the current process into a different session dir
after pi has started.

A profile extension could emulate per-profile memory inside one shared session
system, but it cannot exactly replace per-agent or per-workspace session storage
without support from pi or a remaining launcher layer.

### Workspaces

Runtime profile support is weak for exact equivalence.

Workspace agents currently create a dated directory, `cd` into it, source
`bootstrap.sh`, prepare folders and environment variables, and then launch pi
with a workspace-local session directory.

An extension can create directories and write files after startup, but that is
not the same as launching pi from that cwd with that environment from the
beginning.

If the UX changes, a profile extension could provide commands such as:

```text
/workspace new deepresearch creatine-loading
/workspace resume deepresearch 2026-05-02-...
```

But exact startup semantics still require either pi support for dynamic cwd and
session switching or a small launcher.

### Bootstrap

Runtime profile support is weak when bootstrap means "before pi starts."

The current `bootstrap.sh` can set environment variables, start daemons, perform
preflight checks, write logs, and prepare a workspace before pi initializes.

An extension can run setup after pi starts, but not before providers, settings,
extensions, context files, and sessions are initialized.

This is a major boundary between "agent behavior" and "process-launch behavior."

### Auth, Models, And Settings

Runtime profile support is partial.

Profiles can choose among already-loaded models, read extra config files, and
write local preference files. But pi's native `auth.json`, `models.json`, and
`settings.json` are discovered from the active config root.

A profile extension cannot make the current process behave as if it had started
with a different config root's `auth.json`, `models.json`, or `settings.json`,
unless pi exposes APIs for reloading those concerns at runtime.

### Context Files

Runtime profile support is uncertain and likely incomplete.

The current method can use `--no-context-files` in `pi-args` so an agent does not
inherit repository instructions such as `AGENTS.md`.

A profile extension can filter messages in the `context` hook and inject its own
context, but context-file discovery may already have happened by then. If the
goal is a hard guarantee that repo context files are never loaded for a profile,
that remains a startup flag or requires an earlier pi hook.

### Extension Isolation

Runtime profile support is weak for exact equivalence.

The current method loads only the extensions linked into the selected agent root.
A universal profile extension would normally require loading all shared behavior
up front, then activating or deactivating pieces per profile.

That works for cooperative tools and UI, but it is not hard isolation. Any loaded
extension can still register hooks, commands, and tools. Hiding tools does not
unload hooks.

This may be acceptable if the extension set is trusted and designed as a single
profile platform. It is not equivalent to separate `PI_CODING_AGENT_DIR` roots.

## What Cannot Be Fully Done Today

These behaviors are not meaningfully reducible to an extension with the current
architecture:

- Change `PI_CODING_AGENT_DIR` for the already-running pi process.
- Load a different `extensions/` directory after startup as if it had been the
  original config root.
- Make pi rediscover native `skills/`, `prompts/`, `settings.json`, `auth.json`,
  or `models.json` from a different root after startup.
- Add model providers at runtime if they were not loaded from startup config.
- Choose `--session-dir`, `--continue`, or `--no-session` after the process has
  already initialized session storage.
- Guarantee `--no-context-files` semantics after context-file discovery has
  already occurred.
- Source shell bootstrap before pi starts.
- Start pi inside a newly created workspace cwd without some pre-pi launcher or
  native pi support.
- Provide shell-level commands like `writer`, `browser`, `deepresearch ls`, and
  global `resume` without keeping some command dispatch layer.
- Change JSON print mode and launcher-side output filtering after startup.

These are process-launch behaviors, not agent-behavior choices.

## What Could Be Removed Or Reduced

If dot-pi adopted runtime profiles, the following could likely shrink:

- Many simple standalone agent directories.
- Repeated common extension symlinks.
- Simple `SYSTEM.md` plus `pi-args` agents such as "chat with this model and no
  tools."
- Agent-specific theme, banner, and UI files.
- Some native prompt templates, if extension commands are acceptable.
- Some skill symlinks, if profile-injected skills are acceptable.
- Some model default plumbing, if profile selection owns model choice.

The system would become less filesystem-native and more registry-driven.

## Likely Hybrid Design

A pragmatic design is not "all folders" or "all extension." It is a split:

- Use a universal `agent-profiles` extension for lightweight agents and runtime
  modes.
- Keep config-root agents for hard isolation, workspace agents, and MAS workflows
  that depend on separate process startup.
- Keep a small launcher for shell ergonomics, workspace creation, session-dir
  selection, and print/resume modes.

In this model, `browser`, `writer`, and `lm` could become runtime profiles, while
`deepresearch`, `reader`, and other workspace/MAS agents may remain config roots
unless pi grows runtime APIs for sessions, config reloading, and cwd/workspace
switching.

## Assessment Questions

Use these questions to decide whether a feature must remain in the launcher or
agent directory model:

1. Does this behavior need to happen before pi starts?
2. Does this behavior depend on native discovery from `PI_CODING_AGENT_DIR`?
3. Does this behavior require hard isolation from other loaded extensions?
4. Does this behavior need a separate session directory or workspace cwd?
5. Is prompt injection good enough, or does it need native skill/template
   semantics?
6. Can the UX change from shell command to slash command?
7. Is the feature agent behavior, or process-launch behavior?

If the answer points to runtime agent behavior, an extension can probably own it.
If the answer points to process launch, config discovery, or isolation, some
non-extension layer is still needed.
