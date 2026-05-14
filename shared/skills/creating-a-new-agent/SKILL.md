---
name: creating-a-new-agent
description: Scaffold a new dot-pi standalone or MAS orchestrator agent under agents/<name>/ per repo conventions (symlinks, relink, dispatch).
---

# Creating a new dot-pi agent

When the user asks to add, scaffold, or clone the layout of a **new top-level** dot-pi agent (standalone or MAS orchestrator), do **not** assume removed **`dotpi create`** / **`dotpi create-agent`** commands.

1. **`read`** the canonical checklist at **`docs/reference/creating-a-new-agent.md`** from the dot-pi repo root (**`DOT_PI_DIR`**). Resolve that path relative to the workspace or **`$DOT_PI_DIR`** when executing in a shell.
2. Follow that document step-by-step: directory layout, **`shared/`** symlinks, **`SYSTEM.md`** / **`USAGE.md`** / **`pi-args`**, MAS-only **`top-level-agent-orchestrator`** link if applicable.
3. After filesystem changes, tell the user to run **`dotpi relink`** from the dot-pi root (and **`dotpi symlink-agents`** if **`core/bin`** is not on **`PATH`**).
4. To attach shared skills to the new agent, use **`dotpi link-skill <agent-name> <skill> [...]`** once **`agents/<agent-name>/`** exists.

For durable-only-on-overlay agent roots (future **`dispatch-agent`** support), see GitHub issue **#21** on the dot-pi repository; today configs must exist under **`$DOT_PI_DIR/agents/<name>/`**.
