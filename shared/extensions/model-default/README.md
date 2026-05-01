# Model Default Extension

Interactive in-agent command for viewing and overriding repo-local model defaults. For the terminal picker that can repair global defaults and agent/subagent `.model` overrides, use `dotpi models`.

## Commands

- `/model-default` -- show resolved defaults
- `/model-default agentic` -- override `DEFAULT_AGENTIC_MODEL`
- `/model-default fast` -- override `DEFAULT_FAST_MODEL`
- `/model-default vlm` -- override `DEFAULT_VLM_MODEL`
- `/model-default reset` -- remove `.model` overrides

Current-agent overrides are stored in that agent config root's `.model`, which is local and gitignored. Global defaults remain in repo-root `model-defaults`.
