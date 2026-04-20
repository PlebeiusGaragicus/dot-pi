# Plan Mode Extension

Read-only exploration mode with human-in-the-loop plan approval. The `/plan` command toggles plan mode; the agent drafts a plan, calls `plan_submit`, and the user approves, revises, or stops.

## Files

- `index.ts` -- Command, tool, hooks, and TUI rendering

## Behavior

While planning:

- Active tools restricted to `read`, `grep`, `find`, `ls`, plus `plan_submit`.
- `write`, `edit`, and `bash` are blocked via the `tool_call` hook.
- `before_agent_start` injects a planning-instructions message (`customType: "plan-context"`).
- Plan body must be passed as the `plan` parameter to `plan_submit` (not as plain chat).

On `plan_submit`:

- Interactive: shows a `Plan Review` select with Approve / Revise / Stop.
- Non-interactive: auto-approves and exits to implementation.

On exit:

- Restores the previously active tool set, clears the `PLAN` status badge, and strips stale `plan-context` messages from history via the `context` hook.

## Commands and Tools

- `/plan` -- toggle plan mode (registered via `pi.registerCommand`)
- `plan_submit` tool -- submits the plan; rendered with markdown in the TUI

## Hooks Registered

- `session_start` -- ensures `plan_submit` is removed from active tools when starting fresh in idle state
- `before_agent_start` -- injects planning instructions while in `planning` phase
- `tool_call` -- blocks `write`/`edit`/`bash` while in `planning` phase
- `context` -- strips `plan-context` messages once back in `idle` phase

## Related Docs

- [Writing Extensions](https://PlebeiusGaragicus.github.io/dot-pi/reference/extensions/)
