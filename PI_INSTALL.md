# dot-pi and Pi’s `pi install` mechanism

This document records **what dot-pi is moving toward**, **how Pi’s package install system works**, **options and tradeoffs**, and **how this repository fits** under a `pi install`–centric workflow. It is intended for maintainers and advanced users; it is not a substitute for [docs/install.md](docs/install.md) or [AGENTS.md](AGENTS.md).

**Supported surface (target):** end users install and maintain dot-pi **only** through Pi’s **`pi install`** and **`pi update`**. The **curl `install`** path is **not** part of that surface and **will be removed** so the repo stays simple and aligned with Pi’s package manager.

---

## 1. Goals

### 1.1 Product goals

1. **Vanilla `pi`** — Running `pi` with no custom agent layout should behave like a **normal Pi install**: default agent directory (`~/.pi/agent`), no dot-pi–specific extension bundles unless the user explicitly added them there.

2. **Named agents (`coder`, `mas`, …) are first-class** — Short commands on `PATH` should launch **this repo’s** agent configs (`SYSTEM.md`, `pi-args`, orchestration, workspace bootstrap, etc.) with **`PI_CODING_AGENT_DIR`** pointing at **`agents/<name>/`** inside the **Pi-managed package tree** (see §3). There is **no** supported parallel “clone dot-pi to `~/…` and curl `install`” product flow.

3. **Installable, upgradable shared bundle** — Shared skills, extensions, prompts, and themes should be consumable via Pi’s **first-class** mechanism: **`pi install`** / **`packages`** in `settings.json`, so users can **`pi update`** when the upstream git (or npm) package moves.

4. **Per-agent settings** — Each agent keeps its **own** `settings.json` (theme, models, feature flags, explicit **`extensions` / `skills` / `prompts` / `themes` arrays** replacing symlink farms under `skills/` and similar). Those files should stay **mergeable** without forcing six identical copies of large JSON by hand (tooling: e.g. `dotpi sync` merging a canonical **`packages`** list).

5. **Isolation** — Dot-pi’s **`packages`** entries should **not** live only in `~/.pi/agent/settings.json` if that would force every bare `pi` session to load dot-pi. Prefer **per-agent** `settings.json` (and/or a small **bootstrap** agent dir used only at install time) so vanilla and dot-pi can diverge cleanly.

### 1.2 Operational goals

- **Documented one-liner** for registering the git package, e.g.  
  `PI_CODING_AGENT_DIR="<absolute-path>/.pi-bootstrap" pi install git:https://github.com/<org>/dot-pi`  
  (exact URL, bootstrap path, and whether **`postinstall`** wires **`PATH`** are policy choices; see §2.3, §3, and §5.)

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
- **`PI_CODING_AGENT_DIR=<your-bootstrap-dir>`** → **`bootstrap-dir/settings.json`** receives **`packages`** (does **not** touch **`~/.pi/agent/settings.json`** if that file is separate).

### 2.3 Git packages: `npm install` and lifecycle scripts

Pi does **not** expose a separate “run this script after **`pi install`** / **`pi update`**” API in the package manifest. For **git** sources it **`git clone`**s (or on update: **`fetch`**, **`reset --hard`**, **`git clean -fdx`**) into **`{agentDir}/git/<host>/<path>`**, then runs **`npm install`** in that clone when **`package.json`** exists (see pi-mono **`DefaultPackageManager`** / **`installGit`** / **`updateGit`**).

That means **standard npm lifecycle scripts** in the repo’s **`package.json`**—typically **`postinstall`**—run in the **clone directory** after install and again after dependency install on update. Use them to:

- prepend or symlink **`core/bin`** (and thus **`dispatch-agent`**) onto the user’s **`PATH`**, or
- run one-time or idempotent **migrations** (prefer writing durable state under **`~/.config/…`** or similar—the clone is **`git clean -fdx`’d** on update, so **do not rely on untracked files inside the package tree** for migration bookkeeping).

Security-wise this is the same class of trust as Pi extensions: **`postinstall` runs arbitrary code** during **`pi install`** / **`pi update`**.

### 2.4 What a “package” is

Each **`packages[]`** entry is usually a string:

| Form | Behavior |
|------|----------|
| `npm:@scope/pkg` | npm install (global or prefixed, depending on scope). |
| `https://github.com/user/repo` or `git:github.com/user/repo` | `git clone` under Pi’s cache (e.g. **`~/.pi/agent/git/<host>/<path>/`**), optional `npm install` in clone if `package.json` exists. |
| Local path | Path must exist; recorded in `packages`; no clone. |

Pi then **merges** resources from each installed package root:

- Prefer **`package.json` → `"pi"`** manifest (`extensions`, `skills`, `prompts`, `themes` path arrays / globs).
- Else conventional directories **`extensions/`**, **`skills/`**, **`prompts/`**, **`themes/`** at package root.

### 2.5 `settings.json` arrays (top-level agent config)

Independently of **`packages`**, **`settings.json`** may list:

- **`extensions`**, **`skills`**, **`prompts`**, **`themes`** — arrays of paths (files, dirs, or globs) resolved relative to **`PI_CODING_AGENT_DIR`** for “global” entries.

Pi **resolves** those entries, then **auto-discovers** conventional dirs under the agent dir. Empty or absent dirs avoid duplicate discovery; override patterns (`!`, `+`, `-`) exist for advanced filtering (see pi-mono `DefaultPackageManager`).

### 2.6 Merging `packages` vs merging settings keys

For **settings**, **`deepMergeSettings`** replaces **whole arrays** when the override (e.g. project) sets a key — arrays are not unioned by default. That matters when splitting “vanilla” vs “project” **`packages`**.

---

## 3. On-disk layout: Pi clone as source of truth

After **`pi install git:…dot-pi`** (with default **`PI_CODING_AGENT_DIR`**), Pi keeps a **git clone** under **`{agentDir}/git/<host>/<path>/`** (see **`getGitInstallPath`** in pi-mono; default **`agentDir`** is **`~/.pi/agent`**, so often **`~/.pi/agent/git/...`**). That directory is the **authoritative checkout** for:

- the **`"pi"`** manifest and merged **extensions / skills / prompts / themes**, and  
- **everything else in the repo** at that revision—**including `dispatch-agent`**, **`agents/`**, **`core/bin/`**, **`dotpi`**, and **`shared/`**.

The **Pi-managed clone** is the **only** supported tree for **using** dot-pi as a product. Named agents are first-class when:

1. **`core/bin`** is on **`PATH`** (typically via **`postinstall`** or documented shell config), and  
2. **`dispatch-agent`** runs from that tree so it sets **`PI_CODING_AGENT_DIR`** to **`…/agents/<name>`** under the same root (today it derives **`DOT_PI_DIR`** from its own location).

### 3.1 Repository development vs `pi install`

**Contributors** edit this repository with a normal **`git clone`** of the source and run tests locally; that checkout is **not** a second “supported install” for end users and is unrelated to **`pi update`**. **Consumers** rely solely on **`pi install`** / **`pi update`** against the published git (or npm) package.

### 3.2 `dispatch-agent` and “copy over”

Pi does **not** copy **`dispatch-agent`** into a second home by default. If you need files outside the clone (e.g. **`PATH`** shims in **`~/bin`**), implement that in **`package.json` scripts** (§2.3) or document a manual step. First-class agents only require that **`pi`** can be launched with **`PI_CODING_AGENT_DIR`** pointing at the right **`agents/<name>`** directory—usually next to **`dispatch-agent`** on disk.

### 3.3 User overlay directory (survives `pi update`)

Git package **`pi update`** runs **`git reset --hard`** and **`git clean -fdx`** in the Pi-managed clone, then **`npm install`**. Anything that must **never** be wiped or reverted—user prompt templates, extra skills, **`.service-name.env`** API keys, **`.tts-wpm`**, dot-pi–scoped **`.ssh`** material, etc.—must live **outside** that clone (or be re-materialized after every update by tooling).

**Convention:** a single **overlay root** under Pi’s home, **`~/.pi/dot-pi/`**, referenced by **`DOT_PI_OVERLAY`**. When **`DOT_PI_OVERLAY`** is unset, **`dispatch-agent`** / **`postinstall`** / **`dotpi sync`** should default it to **`$HOME/.pi/dot-pi`** so tooling and extensions share one path. Set **`DOT_PI_OVERLAY`** explicitly to relocate the overlay. This directory is **only** user-owned sidecar data (not the old full-repo **`~/.dot-pi`** curl install).

**Suggested layout:**

```text
$DOT_PI_OVERLAY/
├── .exa.env
├── .tavily.env
├── .ntfy.env
├── .tts-wpm
├── .ssh/                       # optional: dot-pi–scoped ssh keys/config (not the user’s ~/.ssh)
├── agents/
│   ├── mas/
│   │   ├── prompts/            # user slash-command templates merged with shipped mas prompts
│   │   └── skills/             # user SKILL trees merged with shipped mas skills
│   └── coder/
│       ├── prompts/
│       └── skills/
└── (optional) settings.fragments/   # e.g. JSON snippets merged by dotpi after pi update
```

**How Pi picks up extra `prompts` / `skills`:** Pi resolves **`~/…`** in **`settings.json`** arrays (see pi-mono **`DefaultPackageManager`**). Because **`agents/<name>/settings.json`** inside the clone is **tracked**, it is **reset on `pi update`**—do not rely on hand-editing that file alone for overlay paths. Instead:

1. **Tooling merge** — **`dotpi sync`** (or **`postinstall`**) (re)merges canonical shipped **`settings.json`** with overlay-derived entries, e.g. appending **`~/.pi/dot-pi/agents/mas/prompts`** (tilde or absolute paths—Pi does not expand raw **`$VAR`** inside JSON) to **`prompts`** / **`skills`** arrays **after** each **`pi update`**, preserving user-only keys from a fragment under **`$DOT_PI_OVERLAY`**. (Pi’s **`deepMergeSettings`** replaces **whole arrays** when one side sets a key—generators must **union** overlay paths with shipped lists, not overwrite blindly.)

2. **Local `packages` entry** — **`pi install /path/to/overlay-mini-package`** with a tiny **`package.json`** + **`"pi": { "prompts": [...], "skills": [...] }`** pointing at **`$DOT_PI_OVERLAY`** is possible but awkward for per-agent layout; prefer **merged `settings.json`** for clarity.

**Extensions and scripts** that today read repo-root **`.exa.env`**, **`.tavily.env`**, **`.tts-wpm`**, etc., should resolve **`$DOT_PI_OVERLAY/<file>`** first (default **`~/.pi/dot-pi/<file>`**), then fall back to **`$DOT_PI_DIR/<file>`** (package root), so keys survive **`pi update`** once the overlay exists. **`dispatch-agent`** should **`export DOT_PI_OVERLAY`** (defaulting to **`~/.pi/dot-pi`** when unset) so child **`pi`** processes inherit it.

**`shared/auth.json` / `model-defaults`:** same rule—if they must survive reset inside a read-only-feeling tree, prefer **`~/.pi/agent/auth.json`** (existing Pi convention) or mirror into **`$DOT_PI_OVERLAY/`** and symlink/merge per migration docs when that work lands.

---

## 4. Vanilla `pi` vs `coder` / `mas`

### 4.1 Same binary

There is a **single** `pi` executable. Isolation is by **environment and paths**:

- **Vanilla** — **`PI_CODING_AGENT_DIR` unset** → Pi uses **`~/.pi/agent`** and **`~/.pi/agent/settings.json`**. If that file has **no** dot-pi **`packages`**, vanilla sessions do not load dot-pi’s git package merge.

- **Dot-pi agents** — **`PI_CODING_AGENT_DIR=<package-root>/agents/coder`** (etc.) → Pi uses that directory’s **`settings.json`**, **`SYSTEM.md`**, **`pi-args`**, plus merged **`packages`** and explicit arrays. **`<package-root>`** is typically the Pi git clone (or a symlinked layout that preserves relative paths).

### 4.2 How users invoke names on `PATH`

Today **`core/bin/<name>`** symlinks to **`dispatch-agent`**, which resolves **`agents/<name>/`** and runs **`pi`** with **`PI_CODING_AGENT_DIR`** set ([`core/dispatch/main.sh`](core/dispatch/main.sh), [`core/dispatch/invoke.sh`](core/dispatch/invoke.sh)).

That is **not** the only possible implementation — any wrapper that sets **`PI_CODING_AGENT_DIR`** and **`exec`s `pi`** would work — but **`dispatch-agent`** centralizes **`pi-args`**, workspace **`bootstrap.sh`**, help, and **`model-defaults`** loading.

### 4.3 `packages` on six agents (Pattern B)

**One** **`pi install`** run appends to **one** `settings.json` (the **`PI_CODING_AGENT_DIR`** in effect at install time). It does **not** create six installs for six agents.

**Pattern B** (chosen direction): each **`agents/<name>/settings.json`** is **its own file** (theme, models, arrays, …) but each includes the **same logical `packages` list**. To avoid drift, **tooling** (e.g. **`dotpi sync`**) should merge a **canonical** `packages` list (from e.g. **`.pi-bootstrap/packages.json`** or a fragment) into every agent file with **`jq`**, preserving other keys.

**Bootstrap dir (e.g. `.pi-bootstrap/`)** — minimal directory whose **`settings.json`** is the target when running **`PI_CODING_AGENT_DIR=<bootstrap-abs-path> pi install …`** (path can live **inside** the Pi clone after first materialization, or be created ahead of time—policy choice), so **`~/.pi/agent/settings.json`** stays vanilla-clean. After install, sync copies **`packages`** into each agent’s **`settings.json`** (or you symlink only if you accept shared non-package keys — usually not for Pattern B).

---

## 5. Repository layout under `pi install` (target architecture)

Illustrative **target** tree (some pieces may not exist yet; this is the direction described in planning):

```text
~/.pi/dot-pi/                         # $DOT_PI_OVERLAY — user secrets, prompts, skills (see §3.3)
├── .exa.env, .tavily.env, …
└── agents/<name>/{prompts,skills}/

~/.pi/agent/                          # default Pi profile (vanilla); agentDir when PI_CODING_AGENT_DIR unset
├── settings.json                     # no dot-pi packages[] (policy)
├── auth.json
├── models.json
└── git/github.com/<org>/dot-pi/      # Pi’s clone: full repo at installed revision (“package root”)
    ├── package.json                  # "pi": { … } manifest + optional scripts.postinstall for PATH / migrations
    ├── agents/
    │   └── <name>/                   # per-agent PI_CODING_AGENT_DIR targets live here
    ├── core/bin/                     # coder, mas, … → dispatch-agent (first-class commands once on PATH)
    ├── dispatch-agent
    ├── dotpi
    ├── shared/
    └── .pi-bootstrap/                # optional: settings.json target for pi install without polluting vanilla
        ├── settings.json
        └── README.md
```

**Root `package.json`** — Tracked in-repo with **`"private": true`**, **`"pi": { "extensions": [...], "skills": [...], … }`** pointing at **`shared/`** (or subtrees you ship). Pi reads that manifest from the **git clone** under **`{agentDir}/git/...`**.

---

## 6. Alternatives considered (and why `pi install` still helps)

| Approach | Pros | Cons |
|----------|------|------|
| **Symlink-only `shared/`** (status quo) | Simple; one checkout. | No **`pi update`** for shared bundle; upgrades = **`git pull`** in your checkout only. |
| **`pi install` git package** | Pi-native upgrades; **`checkForAvailableUpdates`** can nudge users; **`postinstall`** can wire **`PATH`**. | Materializes under **`{agentDir}/git/...`**; product story assumes that tree is the install root (see §3). |
| **npm publish `@you/dot-pi`** | Same as git from Pi’s POV with `npm:`. | Publishing overhead. |
| **Feynman-style wrapper** (`PI_CODING_AGENT_DIR=~/.feynman/agent`, separate settings home) | Strong isolation from `~/.pi/agent`. | Heavier product layer than dot-pi wants today. |
| **Only `pi install -l` in a project** | Never touches user global `settings.json`. | Awkward for “global agents on PATH everywhere.” |

Dot-pi’s direction: **named agents first-class** from the **Pi-managed package tree**, **`package.json` + `pi install` + `pi update`** as the **only** supported install/upgrade path for users, optional **`postinstall`** for **`PATH`** and migrations, **per-agent `settings.json`** + **synced `packages`** for Pattern B, a documented **`DOT_PI_OVERLAY`** tree for **secrets and user prompts/skills** (§3.3), and **removal** of the **curl `install`** flow from the supported repo surface.

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

- **[`install`](install)** — **Unsupported** under this plan: the **curl-to-bash** installer will be **removed** (or reduced to a short message pointing at **`pi install`**). Do not document or maintain backward compatibility with it; **[`docs/install.md`](docs/install.md)** should describe **`pi install` / `pi update`** only.
- **[`core/commands/sync.sh`](core/commands/sync.sh)** — Today symlinks **`shared/settings.json` → ~/.pi/agent/settings.json`** when missing; **that conflicts with strict vanilla isolation** if **`packages`** are added globally. The migration plan is to **stop** treating **`~/.pi/agent/settings.json`** as the shared file for dot-pi agents and instead keep **`packages`** on **per-agent** (or bootstrap-only) files.
- **[`AGENTS.md`](AGENTS.md)** — Agent authoring rules; **`DOT_PI_OVERLAY`** and per-agent overlay layout (§3.3) are summarized in the local-config table.

---

## 9. Checklist for maintainers shipping this

1. **Add** root **`package.json`** with **`"pi"`** manifest covering everything **`pi install`** should merge, plus **`scripts.postinstall`** (or equivalent) if **`PATH`** wiring or migrations should run on **`pi install`** / **`pi update`**.
2. **Add** **`.pi-bootstrap/`** with documented **`PI_CODING_AGENT_DIR=… pi install git:…`** flow.
3. **Adjust** **`dotpi sync`** (and/or new **`dotpi packages`** command):  
   - merge canonical **`packages`** into each **`agents/*/settings.json`**;  
   - optionally migrate **`skills/`** symlinks → **`settings.json` arrays**.
4. **Revisit** **`shared/settings.json`** ↔ **`~/.pi/agent/settings.json`** symlink policy for vanilla isolation.
5. **Dispatch telemetry vs packages** — **`PI_OFFLINE` removed from `invoke.sh`** so package update UI and installs/updates are not suppressed for dispatched agents; document any Pi-native alternative for telemetry if maintainers add it later.
6. **Document** in **[`docs/install.md`](docs/install.md)** and **this file** the package-root / **`PATH`** model, **`postinstall`** expectations, **`DOT_PI_OVERLAY`** (§3.3), and upgrade commands.
7. **Remove** the root **[`install`](install)** curl script (or replace with a pointer to **`pi install`**); grep the repo for curl one-liners and update **README** / links accordingly.
8. **Implement overlay resolution** — **`dispatch-agent`** exports **`DOT_PI_OVERLAY`** (default **`$HOME/.pi/dot-pi`** when unset); **`postinstall`** / **`dotpi sync`** creates **`~/.pi/dot-pi/`** and **merges** overlay **`prompts`/`skills`** paths into each **`agents/*/settings.json`** after **`pi update`** (union arrays, do not clobber user keys).
9. **Migrate extensions and skills** that read **`.exa.env`**, **`.tavily.env`**, **`.tts-wpm`**, etc., to prefer **`$DOT_PI_OVERLAY`** then **`$DOT_PI_DIR`**; update docs under **`docs/reference/`** and **README**s accordingly.

---

## 10. Summary

| Question | Answer |
|----------|--------|
| What is **`packages`**? | A **`settings.json`** list of **installable sources** (git/npm/local) Pi merges for **extensions/skills/prompts/themes**. |
| Where does git install land? | Under **`{agentDir}/git/<host>/<path>/`** (default **`agentDir`** → **`~/.pi/agent/git/...`**). Same tree holds **`dispatch-agent`**, **`agents/`**, **`core/bin/`**—the supported install root. |
| How do users install dot-pi? | **`pi install`** (git or npm source); ongoing changes via **`pi update`**. **No** supported curl **`install`** path. |
| How do **`coder` / `mas`** work? | **`PI_CODING_AGENT_DIR`** to **`agents/<name>/`** inside the package root, usually via **`dispatch-agent`** + **`core/bin`** on **`PATH`**. |
| How does vanilla **`pi`** stay vanilla? | No **`PI_CODING_AGENT_DIR`**; keep **`~/.pi/agent/settings.json`** free of dot-pi **`packages`** if you want zero merge from dot-pi’s git package. |
| How do upgrades happen? | User runs **`pi update`**; pushes alone do nothing until then. |
| Optional nudge? | Interactive Pi may show package update UI when updates exist; **`dispatch-agent` does not set `PI_OFFLINE`**. Setting **`PI_OFFLINE` yourself** still disables those checks. |
| User prompts, skills, `.env` keys? | **`DOT_PI_OVERLAY`** (default **`~/.pi/dot-pi`**) — §3.3. Merged into Pi via **`settings.json` arrays`** after **`pi update`**; extensions read overlay **then** package root. |

This document should stay aligned with implementation as **`PI_INSTALL`-related** changes land in the repo.
