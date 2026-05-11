# dot-pi and Pi’s `pi install` mechanism

This document records **what dot-pi is moving toward**, **how Pi’s package install system works**, **options and tradeoffs**, and **how this repository fits** under a `pi install`–centric workflow. It is intended for maintainers and advanced users; it is not a substitute for [docs/install.md](docs/install.md) or [AGENTS.md](AGENTS.md).

---

## 1. Goals

### 1.1 Product goals

1. **Vanilla `pi`** — Running `pi` with no custom agent layout should behave like a **normal Pi install**: default agent directory (`~/.pi/agent`), no dot-pi–specific extension bundles unless the user explicitly added them there.

2. **Named agents (`coder`, `mas`, …)** — Short commands on `PATH` should launch **this repo’s** agent configs (`SYSTEM.md`, `pi-args`, orchestration, workspace bootstrap, etc.) with **`PI_CODING_AGENT_DIR`** pointing at `agents/<name>/`.

3. **Installable, upgradable shared bundle** — Shared skills, extensions, prompts, and themes should be consumable via Pi’s **first-class** mechanism: **`pi install`** / **`packages`** in `settings.json`, so users can **`pi update`** when the upstream git (or npm) package moves.

4. **Per-agent settings** — Each agent keeps its **own** `settings.json` (theme, models, feature flags, explicit **`extensions` / `skills` / `prompts` / `themes` arrays** replacing symlink farms under `skills/` and similar). Those files should stay **mergeable** without forcing six identical copies of large JSON by hand (tooling: e.g. `dotpi sync` merging a canonical **`packages`** list).

5. **Isolation** — Dot-pi’s **`packages`** entries should **not** live only in `~/.pi/agent/settings.json` if that would force every bare `pi` session to load dot-pi. Prefer **per-agent** `settings.json` (and/or a small **bootstrap** agent dir used only at install time) so vanilla and dot-pi can diverge cleanly.

### 1.2 Operational goals

- **Documented one-liner** for registering the git package, e.g.  
  `PI_CODING_AGENT_DIR="$DOT_PI_DIR/.pi-bootstrap" pi install git:https://github.com/<org>/dot-pi`  
  (exact URL and bootstrap path are policy choices; see §5.)

- **Optional helpers** — `dotpi packages bootstrap` (or similar) and/or small `core/bin` shims so users rarely type raw env vars.

- **Honest upgrade story** — Pushes to `main` do nothing on disk until the user runs **`pi update`** (or equivalent); Pi may **notify** in interactive mode when updates exist (§7).

---

## 2. How Pi’s install and settings model works

This repo targets [pi-mono](https://github.com/PlebeiusGaragicus/pi-mono) / `@mariozechner/pi-coding-agent` behavior. The following is accurate for that stack.

### 2.1 `pi install <source>`

- **CLI** — `pi install <source> [-l]` runs the package manager’s **`installAndPersist`**: install material to disk, then append the source string to **`packages`** in the appropriate **`settings.json`**.
- **`-l` / `--local`** — Writes **project** `.pi/settings.json` under `cwd` and installs git/npm artifacts under **`.pi/git`**, **`.pi/npm`**. Without `-l`, writes the **agent dir’s** `settings.json` (see below).

### 2.2 Where `packages` is stored

`SettingsManager` uses two scopes on disk:

| Scope   | Path |
|--------|------|
| “Global” (misleading name) | **`$PI_CODING_AGENT_DIR/settings.json`** |
| Project | **`$cwd/.pi/settings.json`** |

`pi install` without `-l` uses **`getAgentDir()`** (from **`PI_CODING_AGENT_DIR`** when set, else default **`~/.pi/agent`**) and updates **`join(agentDir, "settings.json")`**.

So:

- **`PI_CODING_AGENT_DIR` unset** → **`~/.pi/agent/settings.json`** receives **`packages`** (affects vanilla `pi`).
- **`PI_CODING_AGENT_DIR=$DOT_PI_DIR/.pi-bootstrap`** → **`.pi-bootstrap/settings.json`** receives **`packages`** (does **not** touch `~/.pi/agent/settings.json` if that file is separate).

### 2.3 What a “package” is

Each **`packages[]`** entry is usually a string:

| Form | Behavior |
|------|----------|
| `npm:@scope/pkg` | npm install (global or prefixed, depending on scope). |
| `https://github.com/user/repo` or `git:github.com/user/repo` | `git clone` under Pi’s cache (e.g. **`~/.pi/agent/git/<host>/<path>/`**), optional `npm install` in clone if `package.json` exists. |
| Local path | Path must exist; recorded in `packages`; no clone. |

Pi then **merges** resources from each installed package root:

- Prefer **`package.json` → `"pi"`** manifest (`extensions`, `skills`, `prompts`, `themes` path arrays / globs).
- Else conventional directories **`extensions/`**, **`skills/`**, **`prompts/`**, **`themes/`** at package root.

### 2.4 `settings.json` arrays (top-level agent config)

Independently of **`packages`**, **`settings.json`** may list:

- **`extensions`**, **`skills`**, **`prompts`**, **`themes`** — arrays of paths (files, dirs, or globs) resolved relative to **`PI_CODING_AGENT_DIR`** for “global” entries.

Pi **resolves** those entries, then **auto-discovers** conventional dirs under the agent dir. Empty or absent dirs avoid duplicate discovery; override patterns (`!`, `+`, `-`) exist for advanced filtering (see pi-mono `DefaultPackageManager`).

### 2.5 Merging `packages` vs merging settings keys

For **settings**, **`deepMergeSettings`** replaces **whole arrays** when the override (e.g. project) sets a key — arrays are not unioned by default. That matters when splitting “vanilla” vs “project” **`packages`**.

---

## 3. Two directories on disk (no automatic copy between them)

After **`pi install git:…dot-pi`**:

1. **Pi-managed clone** — e.g. **`~/.pi/agent/git/github.com/<org>/dot-pi/`** (exact path from Pi’s `getGitInstallPath`). This is what **`packages`** resolution reads for the **`"pi"`** manifest and bundled trees.

2. **User’s dot-pi checkout** — e.g. **`~/.dot-pi`** (or **`DOT_PI_HOME`**). Holds **`dispatch-agent`**, **`agents/<name>/`**, **`shared/`**, **`dotpi`**, etc.

**Pi does not copy** from (1) into (2). They are independent checkouts unless you add custom sync scripts. Typical roles:

| Tree | Role |
|------|------|
| **`~/.dot-pi`** | Dispatch, per-agent prompts/system, **`dotpi sync`**, optional paths in **`settings.json` arrays** pointing at **`../../shared/...`**. |
| **`~/.pi/agent/git/.../dot-pi`** | Versioned **package** surface for Pi’s loader and **`pi update`**. |

Keeping **both** is valid: **repo** for orchestration and ergonomics; **Pi cache** for installable/upgradable **shared** resources declared in **`package.json`**.

---

## 4. Vanilla `pi` vs `coder` / `mas`

### 4.1 Same binary

There is a **single** `pi` executable. Isolation is by **environment and paths**:

- **Vanilla** — **`PI_CODING_AGENT_DIR` unset** → Pi uses **`~/.pi/agent`** and **`~/.pi/agent/settings.json`**. If that file has **no** dot-pi **`packages`**, vanilla sessions do not load dot-pi’s git package merge.

- **Dot-pi agents** — **`PI_CODING_AGENT_DIR=$DOT_PI_DIR/agents/coder`** (etc.) → Pi uses that directory’s **`settings.json`**, **`SYSTEM.md`**, **`pi-args`**, plus merged **`packages`** and explicit arrays.

### 4.2 How users invoke names on `PATH`

Today **`core/bin/<name>`** symlinks to **`dispatch-agent`**, which resolves **`agents/<name>/`** and runs **`pi`** with **`PI_CODING_AGENT_DIR`** set ([`core/dispatch/main.sh`](core/dispatch/main.sh), [`core/dispatch/invoke.sh`](core/dispatch/invoke.sh)).

That is **not** the only possible implementation — any wrapper that sets **`PI_CODING_AGENT_DIR`** and **`exec`s `pi`** would work — but **`dispatch-agent`** centralizes **`pi-args`**, workspace **`bootstrap.sh`**, help, and **`model-defaults`** loading.

### 4.3 `packages` on six agents (Pattern B)

**One** **`pi install`** run appends to **one** `settings.json` (the **`PI_CODING_AGENT_DIR`** in effect at install time). It does **not** create six installs for six agents.

**Pattern B** (chosen direction): each **`agents/<name>/settings.json`** is **its own file** (theme, models, arrays, …) but each includes the **same logical `packages` list**. To avoid drift, **tooling** (e.g. **`dotpi sync`**) should merge a **canonical** `packages` list (from e.g. **`.pi-bootstrap/packages.json`** or a fragment) into every agent file with **`jq`**, preserving other keys.

**Bootstrap dir (e.g. `.pi-bootstrap/`)** — minimal directory whose **`settings.json`** is the target when running **`PI_CODING_AGENT_DIR=$DOT_PI_DIR/.pi-bootstrap pi install …`**, so **`~/.pi/agent/settings.json`** stays vanilla-clean. After install, sync copies **`packages`** into each agent’s **`settings.json`** (or you symlink only if you accept shared non-package keys — usually not for Pattern B).

---

## 5. Repository layout under `pi install` (target architecture)

Illustrative **target** tree (some pieces may not exist yet; this is the direction described in planning):

```text
~/.pi/agent/                          # default Pi profile (vanilla)
├── settings.json                     # no dot-pi packages[] (policy)
├── auth.json
├── models.json
└── git/github.com/<org>/dot-pi/      # Pi’s clone after `pi install git:…`
    ├── package.json                  # must include "pi": { … } for manifest-driven resources
    ├── extensions/ …
    └── skills/ …

~/…/dot-pi/                            # DOT_PI_DIR — user clone + dispatch
├── package.json                      # same repo: makes git URL a valid Pi package at install time
├── .pi-bootstrap/
│   ├── settings.json                 # receives packages[] during `pi install` when PI_CODING_AGENT_DIR=.pi-bootstrap
│   └── README.md                     # operator docs for install one-liner
├── agents/
│   ├── coder/
│   │   ├── settings.json             # per-agent: prefs + extensions/skills arrays + packages[] (synced)
│   │   ├── SYSTEM.md / APPEND_SYSTEM.md / pi-args / …
│   │   └── auth.json → ../../shared/auth.json   # typical: shared credentials
│   └── mas/ …
├── shared/                           # canonical repo resources (paths from agent settings.json arrays)
├── core/bin/                         # coder, mas, … → dispatch-agent
├── dispatch-agent
└── dotpi
```

**Root `package.json`** — Tracked in-repo with **`"private": true`**, **`"pi": { "extensions": [...], "skills": [...], … }`** pointing into **`shared/`** (or subtrees you intend to ship as the package). That is what Pi reads from the **git clone** under **`~/.pi/agent/git/...`**.

---

## 6. Alternatives considered (and why `pi install` still helps)

| Approach | Pros | Cons |
|----------|------|------|
| **Symlink-only `shared/`** (status quo) | Simple; one checkout. | No **`pi update`** for shared bundle; upgrades = `git pull` in `DOT_PI_DIR` only. |
| **`pi install` git package** | Pi-native upgrades; **`checkForAvailableUpdates`** can nudge users. | Second clone under **`~/.pi/agent/git/...`**; must keep **`packages`** out of vanilla settings if isolation desired. |
| **npm publish `@you/dot-pi`** | Same as git from Pi’s POV with `npm:`. | Publishing overhead. |
| **Feynman-style wrapper** (`PI_CODING_AGENT_DIR=~/.feynman/agent`, separate settings home) | Strong isolation from `~/.pi/agent`. | Heavier product layer than dot-pi wants today. |
| **Only `pi install -l` in a project** | Never touches user global `settings.json`. | Awkward for “global agents on PATH everywhere.” |

Dot-pi’s direction: **keep the repo + dispatch** for named agents, add **root `package.json` + `pi install` + `pi update`** for the **shared bundle**, and use **per-agent `settings.json`** + **synced `packages`** for Pattern B.

---

## 7. Updates and notifications

### 7.1 User action

**Pushes to `main` do not change local disks** until the user runs **`pi update`** (or a targeted update). **`pi install`** only registers a source and materializes the tree; ongoing movement is handled by **`pi update`**.

### 7.2 “Pi knows” something moved

In **interactive** Pi, startup runs **`checkForAvailableUpdates()`** asynchronously; if updates exist, the UI shows **“Package Updates Available”** and suggests running **`pi update`**, listing display names (see pi-mono `interactive-mode.ts`).

**Caveats:**

- **`PI_OFFLINE`** — if set in the environment, Pi skips package update checks (and other network-sensitive package-manager paths) entirely.
- **Dispatch** — **`dispatch-agent` used to set `PI_OFFLINE=1` in [`core/dispatch/invoke.sh`](core/dispatch/invoke.sh)** to cut background network use (including telemetry-style traffic), which also hid **“Package Updates Available”** and interfered with **`pi install` / `pi update`** behavior for **`coder` / `mas`**. **`PI_OFFLINE` is no longer set from dispatch** so those runs match bare **`pi`** for package discovery. Prefer **upstream Pi’s privacy / telemetry settings** (and documented env knobs) over blanket **`PI_OFFLINE`** here if you need tighter limits without losing package-manager ergonomics.
- **Pinned git refs** — may skip auto-update checks per Pi’s rules.
- **Non-interactive modes** — may not show the same UI nudge.

---

## 8. Relationship to existing dot-pi docs and scripts

- **[`install`](install)** — Clones **`DOT_PI_HOME`**, runs **`dotpi sync`**, prepends **`core/bin`** to `PATH`. Becomes **complementary** to **`pi install`**: shell/installer vs Pi package manager.
- **[`core/commands/sync.sh`](core/commands/sync.sh)** — Today symlinks **`shared/settings.json` → ~/.pi/agent/settings.json`** when missing; **that conflicts with strict vanilla isolation** if **`packages`** are added globally. The migration plan is to **stop** treating **`~/.pi/agent/settings.json`** as the shared file for dot-pi agents and instead keep **`packages`** on **per-agent** (or bootstrap-only) files.
- **[`AGENTS.md`](AGENTS.md)** — Agent authoring rules; should eventually describe **`packages` + arrays** alongside symlink bundles.

---

## 9. Checklist for maintainers shipping this

1. **Add** root **`package.json`** with **`"pi"`** manifest covering everything **`pi install`** should merge.
2. **Add** **`.pi-bootstrap/`** with documented **`PI_CODING_AGENT_DIR=… pi install git:…`** flow.
3. **Adjust** **`dotpi sync`** (and/or new **`dotpi packages`** command):  
   - merge canonical **`packages`** into each **`agents/*/settings.json`**;  
   - optionally migrate **`skills/`** symlinks → **`settings.json` arrays**.
4. **Revisit** **`shared/settings.json`** ↔ **`~/.pi/agent/settings.json`** symlink policy for vanilla isolation.
5. **Dispatch telemetry vs packages** — **`PI_OFFLINE` removed from `invoke.sh`** so package update UI and installs/updates are not suppressed for dispatched agents; document any Pi-native alternative for telemetry if maintainers add it later.
6. **Document** in **[`docs/install.md`](docs/install.md)** and **this file** the two-tree mental model and upgrade commands.

---

## 10. Summary

| Question | Answer |
|----------|--------|
| What is **`packages`**? | A **`settings.json`** list of **installable sources** (git/npm/local) Pi merges for **extensions/skills/prompts/themes**. |
| Where does git install land? | Under **`~/.pi/agent/git/...`** (Pi cache), **not** auto-copied into **`DOT_PI_DIR`**. |
| How do **`coder` / `mas`** work? | **`PI_CODING_AGENT_DIR`** to **`agents/<name>/`**, usually via **`dispatch-agent`** + **`core/bin`** on `PATH`. |
| How does vanilla **`pi`** stay vanilla? | No **`PI_CODING_AGENT_DIR`**; keep **`~/.pi/agent/settings.json`** free of dot-pi **`packages`** if you want zero merge from dot-pi’s git package. |
| How do upgrades happen? | User runs **`pi update`**; pushes alone do nothing until then. |
| Optional nudge? | Interactive Pi may show package update UI when updates exist; **`dispatch-agent` does not set `PI_OFFLINE`**. Setting **`PI_OFFLINE` yourself** still disables those checks. |

This document should stay aligned with implementation as **`PI_INSTALL`-related** changes land in the repo.
