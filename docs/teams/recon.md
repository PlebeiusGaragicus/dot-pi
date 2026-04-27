# Recon Team

Fast codebase reconnaissance and implementation planning.

## Agents

### scout

| Field | Value |
|-------|-------|
| Tools | read, grep, find, ls, bash |

Quickly investigates a codebase and returns structured findings (file locations, key code, architecture notes) that another agent can use without re-reading everything. Adjusts thoroughness based on the task.

### planner

| Field | Value |
|-------|-------|
| Tools | read, grep, find, ls |

Takes context from a scout and produces a concrete, numbered implementation plan. Read-only -- does not make changes.

## Prompts

### `/implement`

Full implementation workflow:

1. **scout** gathers relevant code
2. **planner** creates an implementation plan

```
/implement add Redis caching to the session store
```

## Usage

```bash
recon "Find all authentication code and map the auth flow"

# Direct invocation (without the symlink)
PI_CODING_AGENT_DIR=~/dot-pi/agents/recon pi "Map the database schema"
```
