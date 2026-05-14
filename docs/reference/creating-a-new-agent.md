# Creating a new agent

This guide is the canonical checklist for adding a **new** top-level agent directory under **`$DOT_PI_DIR/agents/<name>/`**. It replaces the removed **`dotpi create`** and **`dotpi create-agent`** scaffolds: follow the steps here (or use the **`creating-a-new-agent`** shared skill) and run **`dotpi relink`** when you are done.

**Convention:** **`DOT_PI_DIR`** is the dot-pi repository root (the package clone). **`dispatch-agent`** resolves agent config only at **`$DOT_PI_DIR/agents/<AGENT_NAME>`** today; see [Limitation and future work](#limitation-and-future-work).

For background on layout and overlay behaviour, see [Agent layout](../agent-layout.md), [Standalone agents](../standalone-agents.md), [Multi-agent systems](multi-agent-systems.md), and [Top-level agent MAS](../design/top-level-agent-mas.md).

## Before you start

- Pick a **directory name** that matches the launcher command (lowercase, no spaces; same as future **`core/bin/<name>`** basename).
- Confirm **`agents/<name>/`** does not already exist.
- Keep **`AGENTS.md`** symlink rules in mind: edit implementation under **`shared/`**, not symlink targets under **`agents/*/extensions/`** or **`agents/*/skills/`** unless you intend a one-off.

## After you finish

1. Run **`dotpi relink`** from the dot-pi root so **`core/bin/<name>`**, shared symlinks, overlay skeletons, and **`agents/<name>/bin`** wiring match shipped conventions.
2. If **`core/bin`** is not on your **`PATH`**, run **`dotpi symlink-agents`** (or add it manually).
3. Smoke-test: **`<name> -h`** and an interactive or **`-p`** run.

---

## Shipped common extensions

dot-pi ships a **small fixed set** of shared extensions (TTS **`say`**, **`save`**, turn timer, finish notifications, **`startup-branding`**, etc.) so every **top-level interactive agent** in this repo gets the same baseline UX. The canonical **basename list** lives in **`shared/shipped-common-extensions`** (one name per line; `#` comments and blank lines allowed).

**Wiring:** **`dotpi relink`** and postinstall read that file and create, for each basename **`ext`**:

```text
ln -sf ../../../shared/extensions/ext.ts agents/<name>/extensions/ext.ts
```

Implementations live only under **`shared/extensions/<basename>.ts`** (or larger trees under **`shared/extensions/<dir>/`** for extensions outside this set).

**When adding a new top-level agent:** replicate the same symlinks (or run **`dotpi relink`** after the agent directory exists). **When adding a new common extension:** add the basename to **`shared/shipped-common-extensions`**, add **`shared/extensions/<basename>.ts`**, then relink. **When forking** an agent that should *not* load the full set, omit the corresponding symlinks in **`extensions/`** deliberately; do not edit other agents' trees.

---

## Standalone agent checklist

Use the shipped capability agents (for example **`agents/coder/`**) as a live reference for **`pi-args`**, shipped common extensions, and optional hooks.

### 1. Directory skeleton

Create **`$DOT_PI_DIR/agents/<name>/`** with at least:

| Path | Purpose |
|------|---------|
| **`extensions/<name>/index.ts`** | Stub or real extension; default export **`(pi: ExtensionAPI) => void`**. See [Writing extensions](extensions.md). |
| **`extensions/`** (shipped common) | For each basename in **`shared/shipped-common-extensions`**, symlink **`extensions/<basename>.ts → ../../../shared/extensions/<basename>.ts`**. Easiest: run **`dotpi relink`** after the skeleton exists. |
| **`prompts/`** | Optional slash templates. Symlink **`shared/prompts/introduction.md`** as **`prompts/introduction.md`** (**`../../../shared/prompts/introduction.md`**). |
| **`skills/`** | Start empty; add skills with **`dotpi link-skill <name> <skill>`**. |
| **`themes/`** | Symlink each **`shared/themes/*.json`** as **`../../../shared/themes/<file>.json`**. |

### 2. Root files

| File | Notes |
|------|--------|
| **`README.md`** | Human-facing overview. |
| **`USAGE.md`** | Man-style launcher help for **`<name> help`** / **`-h`**. |
| **`SYSTEM.md`** | Replaces pi’s default system prompt for this agent (unless you use **`APPEND_SYSTEM.md`** only). |
| **`APPEND_SYSTEM.md`** | Optional; appends to pi’s default prompt. |
| **`pi-args`** | Optional; one CLI flag per line (comments with **`#`**). Omit **`--model`** so pi uses **`settings.json`** (pi updates the default when the user changes the model). Add **`--model provider/id`** only to pin a model. |
| **`banner.txt`** | Optional startup branding (ASCII). |

### 3. Shared config symlinks (agent root)

From **`agents/<name>/`**:

```text
ln -sf ../../shared/models.json   models.json
ln -sf ../../shared/auth.json     auth.json
ln -sf ../../shared/settings.json settings.json
ln -sf ../../shared/bin           bin
```

Do **not** replace these with hand-edited JSON at the agent root. Edit credentials and provider catalog via **`~/.pi/agent/auth.json`**, **`dotpi setup`**, and the resolved models file per **`AGENTS.md`**.

### 4. Optional **`AGENT.md`**

YAML + body for legacy **`agent-prompt`** behaviour requires symlinking **`shared/extensions/agent-prompt`** into **`extensions/`**. The old **`dotpi create-agent`** scaffold did not link this; add only if you need that path.

---

## MAS orchestrator checklist

A MAS root is still a single **`PI_CODING_AGENT_DIR`**, but it loads **`top-level-agent-orchestrator`** and delegates to fixed top-level workers **`ask`**, **`scout`**, **`writer`**, **`coder`**, **`web`**.

Use **`agents/mas/`** as the reference tree (or compare to your new directory after relink).

### 1. Extensions

- Link the **same** shipped common extensions as standalone agents (see [Shipped common extensions](#shipped-common-extensions)); **`dotpi relink`** applies **`shared/shipped-common-extensions`** automatically.
- Add **`../../../shared/extensions/top-level-agent-orchestrator`** → **`extensions/top-level-agent-orchestrator`**.

### 2. Prompts, skills, themes, shared links

Same pattern as standalone: **`prompts/introduction.md`**, per-theme symlinks, **`models.json`**, **`auth.json`**, **`settings.json`**, **`bin`**.

### 3. Orchestrator prose

- **`SYSTEM.md`**: orchestration rules, delegation boundaries, workflow expectations.
- **`USAGE.md`**: document **`subagent`** and in-situ / **`DOT_PI_OVERLAY`** session and trace paths; mirror tone of **`agents/mas/USAGE.md`** where helpful.
- **`README.md`**: describe workflows under **`prompts/`** and how workers map to **`agents/<worker>/`**.

Workers are **not** nested under **`agents/<mas>/agents/`**; they remain top-level **`agents/<worker>/`** shipped in the repo.

---

## Do and don’t

**Do**

- Use **relative** symlinks into **`shared/`** as in shipped agents.
- Put durable per-agent overlays under **`$DOT_PI_OVERLAY/<name>/`** for extra **`prompts/`**, **`skills/`**, **`extensions/`**, **`themes/`**; relink merges them into the clone view.
- Run **`dotpi relink`** after adding or renaming an agent directory or changing symlink targets.

**Don’t**

- Commit **`sessions/`** or overlay secrets into the clone.
- Repoint **`models.json`**, **`auth.json`**, or **`settings.json`** at the agent root to non-standard targets without knowing the overlay contract (**`AGENTS.md`**).
- Edit **`shared/`** targets through **`agents/<name>/skills/*`** symlinks; edit **`shared/skills/<skill>/SKILL.md`** instead.

---

## Limitation and future work

Agent config roots must live under **`$DOT_PI_DIR/agents/<name>/`** for **`dispatch-agent`** and **`dotpi link-skill`** to find them today. If your **`DOT_PI_DIR`** is reset on **`pi update`** and you need **overlay-only** agent trees plus first-class **`core/bin`** commands, follow [dot-pi issue #21](https://github.com/PlebeiusGaragicus/dot-pi/issues/21) (planned runtime/relink extensions). Until then, keep a **git-tracked fork or branch** of dot-pi for custom **`agents/<name>/`** trees, or regenerate from this doc after updates.

---

## Related

- [Agent layout](../agent-layout.md)
- [Standalone agents](../standalone-agents.md)
- [Multi-agent systems](multi-agent-systems.md)
- [Writing extensions](extensions.md)
- Shared skill **`creating-a-new-agent`** under **`shared/skills/`** (invoke via **`dotpi link-skill`** for agents that should load it)
