# Agent Layout

Every directory under `agents/<name>/` is a complete `PI_CODING_AGENT_DIR` root. Agent commands set that environment variable, read the selected root, and launch `pi` in the user's current working directory.

## Top-Level Layout

```text
agents/example/
├── README.md
├── USAGE.md
├── SYSTEM.md
├── APPEND_SYSTEM.md
├── pi-args
├── banner.txt
├── bootstrap.sh
├── auth.json -> ../../shared/auth.json
├── models.json -> ../../shared/models.json
├── settings.json -> ../../shared/settings.json
├── bin -> ../../shared/bin
├── extensions/
├── prompts/
├── skills/
├── themes/
└── agents/          # MAS only
```

Most agents use only a subset of these files.

## Root Files

`README.md` is human-facing design prose. `USAGE.md` is launcher help printed by `agent help`, `agent usage`, `-h`, or `--help`.

`SYSTEM.md` replaces Pi's system prompt. `APPEND_SYSTEM.md` appends to Pi's default system prompt.

`pi-args` contains default CLI flags, one per line. Model aliases such as `$DEFAULT_AGENTIC_MODEL` are loaded from `$DOT_PI_OVERLAY/model-defaults`, falling back to clone-local files only for development checkouts.

`bootstrap.sh`, when present, is an in-situ launch hook. It is sourced before pi starts and receives `DOT_PI_DIR`, `DOT_PI_OVERLAY`, `AGENT_NAME`, `AGENT_DIR`, `DOTPI_BOOTSTRAP_PHASE`, and `BOOTSTRAP_LOG`. Workspace mode has been removed; `WORKSPACE_AGENT` and `WORKSPACE_DIR` are not part of the supported runtime contract.

## Shared Config Links

```text
agents/<name>/auth.json -> ../../shared/auth.json -> ~/.pi/agent/auth.json
agents/<name>/models.json -> ../../shared/models.json -> ~/.pi/agent/models.json
agents/<name>/settings.json -> ../../shared/settings.json -> $DOT_PI_OVERLAY/settings.json
```

`auth.json` and `models.json` intentionally use Pi-standard files. `settings.json` is shared among dot-pi agents through the overlay and must not inherit the vanilla `~/.pi/agent/settings.json` package registration.

Install and relink scripts may create `$DOT_PI_OVERLAY/settings.json` if it is missing, but must never overwrite an existing one.

## Resource Directories

`extensions/`, `prompts/`, `skills/`, and `themes/` define what Pi discovers for this agent. Shipped resources are tracked in the package clone, often as symlinks into `shared/`.

User-owned additions live under:

```text
$DOT_PI_OVERLAY/<agent>/extensions/
$DOT_PI_OVERLAY/<agent>/prompts/
$DOT_PI_OVERLAY/<agent>/skills/
$DOT_PI_OVERLAY/<agent>/themes/
```

`postinstall` and `dotpi relink` wire overlay entries into the clone with symlinks. They repair clone-local links after `pi update` without mutating overlay targets.

## Sessions

Session files do not live in the package clone. Dispatch passes:

```text
--session-dir $DOT_PI_OVERLAY/<agent>/sessions/<current-working-directory-key>
```

`agent ls` lists sessions for the current working directory.

## MAS Subagents

MAS roots include an `agents/` directory. A subagent is discovered when it has `SYSTEM.md` or `APPEND_SYSTEM.md`. `USAGE.md` in a subagent root is the invocation contract appended to the orchestrator prompt.

Reusable subagents live under `subagents/<name>/` and can be symlinked into MAS roots.

## Repo-Level Files

`core/bin/<agent>` symlinks are repaired by package postinstall and `dotpi relink`.

`$DOT_PI_OVERLAY/model-defaults`, `$DOT_PI_OVERLAY/local-providers.conf`, `$DOT_PI_OVERLAY/agent-orchestrator.conf`, `.service.env` files, and `.tts-wpm` are user-owned local state. Clone-local fallbacks exist only for development checkouts.
