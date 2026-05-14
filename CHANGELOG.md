# Changelog

All notable changes to this project are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
where practical.

Version lines use **`[MAJOR.MINOR.PATCH] — YYYY-MM-DD`**. New entries go under
**`[Unreleased]`** until a version is shipped.

---

## [Unreleased]

### Fixed

- **Shipped common extension symlinks** use **`extensions/<basename>.ts`** (not bare `<basename>`) so **pi**’s extension discovery picks them up; bare names pointed at `*.ts` targets but were skipped by `discoverExtensionsInDir`, so extensions such as **`say` never ran `registerFlag`** and CLI flags like **`--tts-enable`** failed with “Unknown option”.

## [0.8.4] — 2026-05-14

### Changed

- **Shipped common extensions** ([#29](https://github.com/PlebeiusGaragicus/dot-pi/issues/29)): `model-default`, `run-finish-notify`, `run-timer`, `save`, `say`, and `startup-branding` are implemented as **`shared/extensions/<name>.ts`**. Postinstall and **`dotpi relink`** read **`shared/shipped-common-extensions`** and symlink each basename into **`agents/<agent>/extensions/`**.

### Removed

- **`shared/extensions-common/`** (symlink bundle directory): replaced by **`shared/shipped-common-extensions`** plus direct symlinks to **`shared/extensions/<name>.ts`**.

## [0.8.3] — 2026-05-13

### Added

- **[`docs/reference/creating-a-new-agent.md`](docs/reference/creating-a-new-agent.md)** — canonical checklist for new standalone or MAS orchestrator roots under **`agents/<name>/`**, replacing removed scaffolds.
- Shared skill **`creating-a-new-agent`** under **`shared/skills/creating-a-new-agent/`** — points agents at the reference doc; link with **`dotpi link-skill <agent> creating-a-new-agent`**.

### Changed

- **`docs/architecture.md`**: expanded install model (Pi `packages[]`, clone lifecycle, nested-clone pitfall, clone+overlay symlinks); corrected MAS diagram for **`top-level-agent-orchestrator`** ([#23](https://github.com/PlebeiusGaragicus/dot-pi/issues/23)).
- **`docs/install.md`**: maintainer cross-link to architecture; explicit warning not to register dot-pi inside **`agents/*/settings.json`** ([#23](https://github.com/PlebeiusGaragicus/dot-pi/issues/23)).

### Removed

- **`dotpi create`**, **`dotpi create-mas`**, and **`dotpi create-agent`**: removed from the **`dotpi`** CLI; **`core/commands/create.sh`** and **`core/commands/create-agent.sh`** removed. Scaffold new agents with **`docs/reference/creating-a-new-agent.md`** and the **`creating-a-new-agent`** skill, then run **`dotpi relink`**.
- **`PI_INSTALL.md`** and the repo-root **`install`** stub: Pi-package architecture is documented in **`docs/architecture.md`** and **`docs/install.md`** ([#23](https://github.com/PlebeiusGaragicus/dot-pi/issues/23)).
- **`dotpi doctor`**: the deprecated stub command is gone; use **`dotpi relink`** to repair local wiring.
- **`dotpi sync`**: removed from the **`dotpi`** CLI; use **`dotpi relink`** (**[`core/commands/relink.sh`](core/commands/relink.sh)**).

## [0.8.2] — 2026-05-13

### Added

- **Postinstall** installs Playwright Chromium for **`core/utilities/browser-runtime`** (browser-control) after relink, unless **`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD`**, **`DOT_PI_SKIP_PLAYWRIGHT_INSTALL`**, or **`CI`** is set; install failures are warnings only so **`pi update`** still completes.

## [0.8.1] — 2026-05-12

### Added

- **`/kid-story`** workflow prompt ([`agents/mas/prompts/kid-story.md`](agents/mas/prompts/kid-story.md)): three parallel **`writer`** brainstorm files under **`ideas/`**, then one **`writer`** narrator producing **`story.md`** (≤500 words) from user settings and a premise seed.
- **`/retro`** workflow prompt ([`agents/mas/prompts/retro.md`](agents/mas/prompts/retro.md)): one cwd-scoped **`scout`** pass plus read-only **`coder`** analysis of a **`/name`d** `mas` session; correlates **`sessions/<cwd-key>/`** with **`subagent-traces/<run-id>/`** by grepping the orchestrator **`*.jsonl`** for the **`dotpi.subagent-traces`** session **`custom`** entry (written on first **`subagent`** delegation).
- **`top-level-agent-orchestrator`**: on first **`subagent`** in a run, append session **`custom`** entry **`dotpi.subagent-traces`** (`traceRunId`, `traceDirRelativeToDotPiOverlay`, etc.) for **`/retro`** and tooling (**not** sent to the LLM).
- **`top-level-agent-orchestrator`**: cap concurrent worker child processes for **`lmstudio`** and **`ollama`** (shared slot, default one) so parallel `subagent` `tasks[]` does not overload local inference; other providers stay parallel up to the existing task cap.

### Changed

- **`top-level-agent-orchestrator`**: removed optional **`parentSession*`** fields from trace **`manifest.json`** (superseded by the **`dotpi.subagent-traces`** session custom entry for correlating orchestrator JSONL with trace bundles).
- **`/retro`** and **`mas`** system prompt: orchestrator must delegate **`scout`** first under **`DOT_PI_OVERLAY`** only; copy-paste **`scout`** task template; forbid overlay probing before delegation.
- **Breaking:** **`$DOT_PI_OVERLAY`** user config uses visible **`env.*`** filenames only (**`env.exa`**, **`env.tavily`**, **`env.ntfy`**, **`env.tts-wpm`**, per-agent **`env.model`**, optional **`env.ssh`** text file). Older dotfiles and **`env.*.env`** names are not read—migrate existing keys into the new paths. Resolution is overlay-only (no package-clone fallbacks). ([#9](https://github.com/PlebeiusGaragicus/dot-pi/issues/9))
- **`overlayFirstFile`**, **`agentOverlayFirstFile`**, and **`core/dispatch/pi-args.sh`** resolve **`model-defaults`**, provider **`env.*`** files, **`env.tts-wpm`**, and per-agent **`env.model`** under **`$DOT_PI_OVERLAY`** only (no reads from the Pi-managed package clone for that durable user state).
- Document contributor **local development** (git clone, `npm install`, prepend clone `core/bin` to `PATH`) in **`README.md`**; cross-references in **`docs/install.md`** and **`docs/index.md`**.

### Removed

- **`top-level-agent-orchestrator`**: **`orchestrator-session.jsonl`** symlink inside each **`subagent-traces/<run-id>/`** bundle (**breaking** for external tooling that relied on it). Use the **`dotpi.subagent-traces`** **`custom`** line in the orchestrator session file instead.

---

## [0.8.0] — 2026-05-11

_Remove nested **`agent-orchestrator`** and subagent relink stack; MAS worker traces under **`$DOT_PI_OVERLAY`**; **`top-level-agent-orchestrator`**-only dispatch and **`dotpi create`**._

### Removed

- **`shared/extensions/agent-orchestrator`** (nested MAS worker discovery and provider-aware scheduling).
- Repo-root sample configs **`agent-orchestrator.conf`** and **`local-providers.conf`** (only consumed by the removed extension).
- **`shared/extensions-subagents/`** bundle and postinstall/relink wiring for **`subagents/*/`** and **`agents/<mas>/agents/*/`** nested pools.
- **`docs/reference/subagent-concurrency.md`** (MkDocs nav entry removed).

### Changed

- **`dotpi create`** scaffolds MAS configs with **`top-level-agent-orchestrator`** and updated README / USAGE / SYSTEM templates for capability-agent delegation.
- **`core/dispatch/main.sh`** and **`dotpi list`**: MAS detection uses only **`top-level-agent-orchestrator`**.
- **`shared/extensions/lib/dotpi-paths.ts`**: dropped **`subagents/`**-specific overlay mapping.
- Design doc **`docs/design/top-level-agent-mas.md`** and reference docs now describe the shipped top-level worker model as the supported path (historical note on removed nested stack).
- **MAS** (`top-level-agent-orchestrator`): worker **`subagent`** trace JSONL and
  **`manifest.json`** are written under **`$DOT_PI_OVERLAY/<agent>/subagent-traces/<run-id>/`**
  (e.g. **`~/.pi/dot-pi/mas/subagent-traces/...`**) instead of under the dot-pi git clone.

### Breaking

- Custom MAS trees that symlinked **`agent-orchestrator`**, relied on automatic relink into **`subagents/`** or **`agents/<mas>/agents/`**, or used **`local-providers.conf`** / **`agent-orchestrator.conf`**, must migrate to **`top-level-agent-orchestrator`**, vendor the old extension, or wire nested configs manually.

---

## [0.7.0] — 2026-05-11

_Pi package install and postinstall wiring; **`$DOT_PI_OVERLAY`** (`~/.pi/dot-pi/<agent>/`); shared **`auth.json`** / **`models.json`** / **`bin`**; **`mas`** without shipped **`subagents/`**._

### Added

- **`$DOT_PI_OVERLAY`** (default **`~/.pi/dot-pi`**) as the durable home for user-owned
  and runtime state outside the Pi-managed package clone. Each top-level agent name
  gets a subtree **`~/.pi/dot-pi/<agent>/`** with `sessions/`, `prompts/`, `skills/`,
  `extensions/`, and `themes/`, plus a `bin` hop that resolves to **`~/.pi/agent/bin`**
  so helper binaries stay shared across agents and **`pi update`**.
- **`core/install/lib.sh`** and **`core/install/postinstall.sh`** as the shared
  install and **`dotpi relink`** implementation for symlink and overlay wiring.

### Changed

- **Installation surface** is **`pi install` / `pi update`** on this repo as a Pi git
  package. Postinstall prints PATH hints and runs **`dotpi relink`** wiring; large
  legacy **`install`** script behavior was folded into the package lifecycle.
- **`shared/auth.json`** and **`shared/models.json`** are symlinked through the overlay
  to **`~/.pi/agent/auth.json`** and **`~/.pi/agent/models.json`** so credentials and
  the provider catalog stay canonical for both vanilla **`pi`** and dispatched agents.
- **`mas`** orchestration is documented as delegating to **top-level capability agents**
  (`ask`, `scout`, `writer`, `coder`, `web`) via prompts and traces, instead of owning a
  separate shipped nested worker pool under **`subagents/`**.

### Removed

- **`subagents/`** as a shipped directory of reusable subagent configs (collector,
  editor, scout, writer trees). **`dotpi relink`** still wires **`subagents/*/`** if
  you create that layout locally.
- **Workspace-agent mode** (`WORKSPACE_AGENT`, **`core/dispatch/workspace.sh`**, dated
  **`workspaces/`** flows): all top-level agents run **in-situ** in the user’s cwd;
  sessions live under the overlay.

---

## [0.6.0] — 2026-05-07

_No curated notes in this file; see `git log` for changes before 0.7.0._
