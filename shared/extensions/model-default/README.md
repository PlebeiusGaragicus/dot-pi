# Model Default Extension

Interactive command for viewing and overriding repo-local model defaults.

## Commands

- `/model-default` -- show resolved defaults
- `/model-default agentic` -- override `DEFAULT_AGENTIC_MODEL`
- `/model-default fast` -- override `DEFAULT_FAST_MODEL`
- `/model-default vlm` -- override `DEFAULT_VLM_MODEL`
- `/model-default reset` -- remove **`env.model`** overrides

Current-agent overrides are stored in **`env.model`** under **`$DOT_PI_OVERLAY/<agent>/`**, which is gitignored. Global defaults live in **`$DOT_PI_OVERLAY/model-defaults`**.
