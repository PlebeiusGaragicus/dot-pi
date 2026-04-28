# Run Timer Extension

Shows elapsed time for each agent run in the TUI status line.

## Files

- `index.ts` -- Lifecycle hooks and elapsed-time status rendering

## Behavior

- Starts timing on `before_agent_start`.
- Updates the status line once per second while the agent is running.
- Shows `Running: 00:00` during the turn.
- Replaces it with `Trajectory time: 00:00` when `agent_end` fires.
- Uses `HH:MM:SS` for runs longer than one hour.
- Skips non-interactive runs where no TUI is available.

## Hooks Registered

- `before_agent_start`
- `agent_end`
