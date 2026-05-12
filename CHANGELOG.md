# Changelog

All notable changes to this project are documented in this file.

The format is inspired by [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html)
where practical.

Version lines use **`[MAJOR.MINOR.PATCH] — YYYY-MM-DD`**. New entries go under
**`[Unreleased]`** until a version is shipped.

---

## [Unreleased]

_No entries yet._

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
- **`dotpi sync`** and **`dotpi doctor`** are deprecated on the supported product path
  (see **`PI_INSTALL.md`**).

---

## [0.6.0] — 2026-05-07

_No curated notes in this file; see `git log` for changes before 0.7.0._
