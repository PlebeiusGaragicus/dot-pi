# Model Defaults

dot-pi uses `pi-args` as the canonical place where each agent chooses its model policy. The model default feature gives those `pi-args` files stable aliases, while still allowing local user preferences, inline environment overrides, and pi's own `settings.json` default.

## Files And Commands

### `$DOT_PI_OVERLAY/model-defaults`

Overlay-owned local config. It is created by postinstall/relink or `dotpi model-defaults` if missing, and can be managed with:

```bash
dotpi model-defaults
```

It defines fallback aliases:

```sh
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
```

The `${VAR:-...}` form is intentional: inline environment variables keep priority over the file.

`model-defaults` is loaded at agent launch time by `dispatch-agent` after the current agent config root is known. Child worker processes launched by **`top-level-agent-orchestrator`** inherit the same environment and load each worker’s own `pi-args` and `.model` from that worker’s `PI_CODING_AGENT_DIR`. The overlay path is preferred; clone-local files are only a development fallback.

### Agent `.model`

Optional agent-local override file, written by the in-agent command:

```text
/model-default
```

Agent `.model` files live under `$DOT_PI_OVERLAY` and contain one raw model id for that specific agent config root:

```text
lmstudio/nvidia/nemotron-3-super
```

With no arguments, the command opens an interactive menu. If the current agent's `pi-args` contains a model alias such as `$DEFAULT_FAST_MODEL`, the first option writes a direct current-agent model override:

```text
Set current agent model
Set global agentic default
Set global fast default
Set global vision default
Show current defaults
Reset current agent override
```

The direct commands still work:

```text
/model-default agentic
/model-default fast
/model-default vlm
/model-default global agentic
/model-default global fast
/model-default global vlm
/model-default show
/model-default reset
```

### `pi-args`

Each agent or subagent references the alias it wants:

```text
--model
$DEFAULT_FAST_MODEL
--thinking
off
```

If `$DEFAULT_FAST_MODEL` expands to an empty value, `dispatch-agent` drops the `--model` flag before launching pi. That lets pi fall back to its normal `settings.json` default instead of receiving a dangling `--model`.

## Selection Precedence

Model selection resolves in this order:

1. Inline environment overrides:

   ```bash
   DEFAULT_AGENTIC_MODEL=provider/model-name deepresearch
   ```

2. Agent-local `.model` overrides written by `/model-default`.
3. Overlay `model-defaults` values written by `dotpi model-defaults`.
4. Pi's `settings.json` default, reached when no non-empty model value resolves.

## Target Behavior

- Agent policy lives in `pi-args`, not a separate model policy file.
- `model-defaults` supplies machine-local global fallback aliases.
- Agent `.model` files supply persistent per-agent raw model overrides without editing `pi-args`.
- Inline env overrides are temporary and highest priority among defaults.
- Empty default aliases are valid and result in no `--model` flag being passed.

This makes both of these valid:

```bash
deepresearch
DEFAULT_AGENTIC_MODEL=provider/model-name deepresearch
```

## Typical Agent Policies

Interactive/lightweight agents often use the fast default:

```text
--model
$DEFAULT_FAST_MODEL
```

General coding or orchestration agents usually use the agentic default:

```text
--model
$DEFAULT_AGENTIC_MODEL
```

Vision-heavy subagents use the VLM default:

```text
--model
$DEFAULT_VLM_MODEL
```

## Thinking

Thinking is not part of the model-default alias system. Agents that need a fixed thinking policy should hardcode it in `pi-args`:

```text
--thinking
off
```

Agents that should use pi's provider default should leave `--thinking` out.

## Runtime Flow

```mermaid
flowchart TD
  inlineEnv["Inline environment"] --> modelEnv["Resolved DEFAULT_* env"]
  dotModel["Agent .model overrides"] --> modelEnv
  modelDefaults["model-defaults fallbacks"] --> modelEnv
  piArgs["Agent pi-args"] --> expand["Expand env vars"]
  modelEnv --> expand
  expand --> filter["Drop empty model flags"]
  filter --> launch["Launch pi"]
  piSettings["pi settings.json default"] --> launch
```

## Child worker processes

MAS worker invocations are separate pi config roots (`agents/ask`, `agents/scout`, etc.). Each worker’s own `pi-args` is read before launch, with the same model-default behavior as any top-level agent:

- Load that worker’s own `.model` and overlay `model-defaults`.
- Expand `$DEFAULT_*` in the worker’s `pi-args`.
- Drop empty `--model` values.

This keeps orchestrators, standalone agents, and delegated workers on one model selection mechanism.
