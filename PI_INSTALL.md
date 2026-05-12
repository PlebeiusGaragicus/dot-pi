# dot-pi and Pi’s `pi install` mechanism

This document records **what dot-pi is moving toward**, **how Pi’s package install system works**, **options and tradeoffs**, and **how this repository fits** under a `pi install`–centric workflow. It is intended for maintainers and advanced users; it is not a substitute for [docs/install.md](docs/install.md) or [AGENTS.md](AGENTS.md).

**Supported surface (target):** end users install and maintain dot-pi **only** through ordinary Pi **`pi install`** and **`pi update`**. The **curl `install`** path is **not** part of that surface and **will be removed** so the repo stays simple and aligned with Pi’s package manager.

**Non-goals (target):** there is **no** reliance on **`dotpi sync`** (or any periodic merge job) for correct behavior. **`dotpi sync`** and **`dotpi doctor`** are **deprecated** and will be removed from the supported product surface. **`packages[]`** carries the **install/update lifecycle** for the Pi-managed dot-pi clone; **`dispatch-agent`** and **symlink-defined trees under each `agents/<name>/`** (extensions, skills, prompts, themes) carry the named-agent **runtime shape**. **`settings.json`** is for Pi preferences and package registration, **not** for enumerating every shipped extension/skill/prompt/theme path. **Workspace agents** (dated **`workspaces/`** dirs, **`WORKSPACE_AGENT`**, **`bootstrap.sh`** workspace mode) are **removed** from the target architecture—all agents run **in-situ** like ordinary Pi sessions, with **session files** stored under **`~/.pi/dot-pi/<agent>/sessions/`** or an equivalent per-cwd subtree under that overlay.

---

## Comprehensive directory tree (target)

Illustrative layout on a machine where **`PI_CODING_AGENT_DIR`** defaults to **`~/.pi/agent`** for vanilla **`pi`**, dot-pi installs as a **git package** under that agent dir, and **`DOT_PI_OVERLAY`** defaults to **`~/.pi/dot-pi`**. Paths under **`git/`** use example host **`github.com/PlebeiusGaragicus/dot-pi`**; Pi’s real segment follows **`getGitInstallPath`** in pi-mono.

```text
~/.pi/
├── agent/                                           # PI_CODING_AGENT_DIR when unset (vanilla pi)
│   ├── settings.json                                # contains packages[] entry for dot-pi; manifest is inert for vanilla resources
│   ├── auth.json                                    # Pi credential store (shared with dispatched agents)
│   ├── models.json                                  # provider/model catalog (shared)
│   ├── sessions/                                    # optional: sessions for bare `pi` only
│   └── git/
│       └── github.com/
│           └── PlebeiusGaragicus/
│               └── dot-pi/                          # PACKAGE ROOT — Pi-managed clone (git reset/clean on update)
│                   ├── package.json                 # "private": true, inert "pi" manifest, scripts.postinstall (PATH, overlay wiring)
│                   ├── package-lock.json            # if npm deps exist
│                   ├── dispatch-agent
│                   ├── dotpi                          # legacy CLI; sync/doctor deprecated (see §8 checklist)
│                   ├── VERSION
│                   ├── AGENTS.md
│                   ├── PI_INSTALL.md
│                   ├── core/
│                   │   ├── bin/                     # first-class commands on PATH after postinstall
│                   │   │   ├── mas                  # → ../../dispatch-agent
│                   │   │   ├── coder
│                   │   │   ├── ask
│                   │   │   └── dotpi                # optional symlink to ../../dotpi (sync/doctor deprecated)
│                   │   ├── commands/                # dotpi subcommands (shrunken surface; sync.sh/doctor.sh gone)
│                   │   ├── dispatch/                # dispatch-agent: PI_CODING_AGENT_DIR, --session-dir, DOT_PI_OVERLAY
│                   │   └── tests/
│                   │
│                   ├── agents/                      # shipped agent PI_CODING_AGENT_DIR roots (see §3.4)
│                   │   ├── mas/
│                   │   │   ├── SYSTEM.md
│                   │   │   ├── pi-args
│                   │   │   ├── settings.json        # Pi prefs only; not dot-pi package registration (§3.5)
│                   │   │   ├── prompts/             # shipped + symlinks into shared/ and (via postinstall) overlay
│                   │   │   ├── extensions/          # symlink bundle → shared/extensions… (shipped “vanilla dot-pi”)
│                   │   │   ├── skills/
│                   │   │   ├── themes/
│                   │   │   ├── USAGE.md
│                   │   │   └── README.md
│                   │   ├── coder/
│                   │   ├── ask/
│                   │   └── …                        # other shipped agents
│                   │
│                   ├── shared/
│                   │   ├── extensions/              # TypeScript extension source
│                   │   ├── skills/
│                   │   ├── themes/
│                   │   ├── prompts/
│                   │   └── bin/                     # fd, rg, … (often gitignored populated by pi)
│                   │
│                   ├── docs/                        # MkDocs source
│                   ├── mkdocs.yml
│                   └── …                            # remaining repo files
│
└── dot-pi/                                          # DOT_PI_OVERLAY — default $HOME/.pi/dot-pi (survives pi update)
    ├── .exa.env                                     # optional API keys (convention; not shipped in clone)
    ├── .tavily.env
    ├── .ntfy.env
    ├── .tts-wpm
    ├── model-defaults                               # optional: local model aliases
    ├── settings.json                                # optional shared dot-pi prefs file; no dot-pi self package (§3.5)
    ├── .ssh/                                        # optional dot-pi–scoped ssh material (not ~/.ssh)
    │
    ├── mas/                                         # per-agent overlay (name matches agents/<name>/)
    │   ├── sessions/                                # --session-dir target for `mas`
    │   ├── prompts/                                 # user slash templates (additive; wired from clone via symlinks)
    │   ├── skills/                                  # user SKILL trees
    │   ├── extensions/                              # optional user / third-party extensions
    │   └── themes/                                  # optional user themes
    ├── coder/
    │   ├── sessions/
    │   ├── prompts/
    │   ├── skills/
    │   ├── extensions/
    │   └── themes/
    └── …                                            # one subtree per agent that receives overlay content
```

**Vanilla vs dot-pi:** **`~/.pi/agent/settings.json`** may contain dot-pi’s **`packages[]`** entry so ordinary **`pi update`** works. Vanilla **`pi`** stays behaviorally clean because dot-pi’s root package manifest is intentionally inert and exposes no package-root extensions, skills, prompts, or themes to vanilla package loading. Dispatched agents load dot-pi resources from their own **`PI_CODING_AGENT_DIR=…/agents/<name>`** filesystem trees.

---

## 1. Goals

### 1.1 Product goals

1. **Vanilla `pi`** — Running `pi` with no custom agent layout should behave like a **normal Pi install** even though **`~/.pi/agent/settings.json`** contains dot-pi’s package registration. Dot-pi avoids vanilla behavior changes by making the package-root **`"pi"`** manifest inert: the package can be updated, but vanilla **`pi`** does not load dot-pi extensions, skills, prompts, or themes from the package root.

2. **Named agents (`coder`, `mas`, …) are first-class** — Short commands on `PATH` launch **this repo’s** agent configs (`SYSTEM.md`, `pi-args`, orchestration, etc.) with **`PI_CODING_AGENT_DIR`** pointing at **`agents/<name>/`** inside the **Pi-managed package tree** (see §3). There is **no** supported parallel “clone dot-pi to `~/…` and curl `install`” product flow.

3. **Installable, upgradable clone** — The dot-pi **git package** is registered with Pi via ordinary **`pi install git:…dot-pi`**. Pi owns the clone and update lifecycle under **`~/.pi/agent/git/<host>/<path>/`**. The package-root **`"pi"`** manifest is omitted or intentionally inert so package registration does **not** become the runtime source of dot-pi resources for vanilla **`pi`**.

4. **Symlink-first agent shape** — Which extensions, skills, prompts, and themes an agent loads is defined by **directory layout + symlinks** under **`…/dot-pi/agents/<name>/`** (e.g. bundles to **`shared/`**, and **`postinstall`**–maintained links into **`$DOT_PI_OVERLAY/<name>/…`**). Pi **auto-discovers** those trees under **`PI_CODING_AGENT_DIR`**. **`settings.json` does not replace** that model with large **`extensions` / `skills` / `prompts` / `themes` arrays** (optional minimal overrides only if ever needed).

5. **Runtime isolation** — Dot-pi’s package registration may live in **`~/.pi/agent/settings.json`**, but dot-pi behavior does not. Each dispatched agent reads **`agents/<name>/settings.json`** (tracked, and/or **symlinked** to a single **`~/.pi/dot-pi/settings.json`** if the project chooses one shared prefs file—policy documented in implementation) and discovers resources from its own filesystem tree.

6. **Sessions outside the clone** — **`dispatch-agent`** passes **`--session-dir`** (or equivalent Pi flag) pointing at **`$DOT_PI_OVERLAY/<AGENT_NAME>/sessions`** (default **`~/.pi/dot-pi/<agent>/sessions`**), so session history survives **`git clean -fdx`** on **`pi update`**.

### 1.2 Operational goals

- **Documented one-liner** for registering the git package, e.g.  
  `pi install git:https://github.com/<org>/dot-pi`  
  (exact URL, host shorthand, and optional pinned refs are policy choices; see §2.3, §3, and §4.3.)

- **`postinstall`** — Ensures **`core/bin`** is on **`PATH`** (or prints exact shell lines); creates **`$DOT_PI_OVERLAY/<agent>/{sessions,prompts,skills,extensions,themes}`** skeleton dirs; **recreates clone → overlay symlinks** under each **`agents/<agent>/`** after **`git clean -fdx`** (see §3.4). Optionally prints **`export DOT_PI_OVERLAY`** for login shells.

- **Honest upgrade story** — Pushes to `main` do nothing on disk until the user runs **`pi update`** (or equivalent); Pi may **notify** in interactive mode when updates exist (§6).

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

- **`PI_CODING_AGENT_DIR` unset** → **`~/.pi/agent/settings.json`** receives **`packages`**. This is dot-pi’s target because it keeps ordinary **`pi update`** working without a special environment variable.
- **`PI_CODING_AGENT_DIR=<some-other-dir>`** → **`some-other-dir/settings.json`** receives **`packages`** and git packages install under **`some-other-dir/git/...`**. This can isolate settings, but it also requires special update commands and is not the minimal supported product path.

**Important:** because git packages install under the active **`agentDir`**, dot-pi’s runtime agent dirs **must not** list dot-pi itself in **`packages[]`**. If **`agents/coder/settings.json`** listed **`git:...dot-pi`**, Pi would look under **`agents/coder/git/<host>/<path>/`** and could create a nested dot-pi clone.

### 2.3 Git packages: `npm install` and lifecycle scripts

Pi does **not** expose a separate “run this script after **`pi install`** / **`pi update`**” API in the package manifest. For **git** sources it **`git clone`**s (or on update: **`fetch`**, **`reset --hard`**, **`git clean -fdx`**) into **`{agentDir}/git/<host>/<path>`**, then runs **`npm install`** in that clone when **`package.json`** exists (see pi-mono **`DefaultPackageManager`** / **`installGit`** / **`updateGit`**).

That means **standard npm lifecycle scripts** in the repo’s **`package.json`**—typically **`postinstall`**—run in the **clone directory** after install and again after dependency install on update. Use them to:

- prepend or symlink **`core/bin`** (and thus **`dispatch-agent`**) onto the user’s **`PATH`**, or
- create **`~/.pi/dot-pi/<agent>/{sessions,prompts,skills,extensions,themes}`** skeleton directories idempotently, or
- **recreate symlinks** from **`agents/<agent>/…`** into **`$DOT_PI_OVERLAY`** (untracked links inside the clone are removed by **`git clean -fdx`**), or
- run one-time or idempotent **migrations** (prefer durable state under **`~/.pi/dot-pi/`** or **`~/.config/…`**).

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

This merge is about the **installed git/npm package** (dot-pi repo root). Dot-pi’s root package should therefore be **inert** for vanilla resource loading: either omit root conventional resource directories, or define a root **`"pi"`** manifest with no resources exposed. Named agents still rely on **`agents/<name>/`** filesystem discovery; package registration is only the clone/update mechanism.

### 2.5 `settings.json` arrays (top-level agent config)

Pi **may** list **`extensions`**, **`skills`**, **`prompts`**, **`themes`** in **`settings.json`**. Pi **resolves** those entries, then **auto-discovers** conventional dirs under **`PI_CODING_AGENT_DIR`**. Dot-pi’s **target** is to rely on **discovery + symlinks** under **`agents/<name>/`** and keep runtime agent **`settings.json`** focused on Pi UI prefs, defaults, and optional local overrides—**not** dot-pi self-registration and **not** the full shipped resource inventory.

### 2.6 Merging `packages` vs merging settings keys

For **settings**, **`deepMergeSettings`** replaces **whole arrays** when the override (e.g. project) sets a key — arrays are not unioned by default. That matters if project settings define their own **`packages`**, **`extensions`**, **`skills`**, **`prompts`**, or **`themes`** arrays.

---

## 3. On-disk layout: Pi clone as source of truth

After ordinary **`pi install git:…dot-pi`** with **`PI_CODING_AGENT_DIR`** unset, Pi keeps a **git clone** under **`~/.pi/agent/git/<host>/<path>/`**. That directory is the **authoritative checkout** for:

- the root **`package.json`** lifecycle scripts and inert package manifest, and  
- **everything else in the repo** at that revision—**including `dispatch-agent`**, **`agents/`**, **`core/bin/`**, **`dotpi`**, and **`shared/`**.

The **Pi-managed clone** is the **only** supported tree for **using** dot-pi as a product. Named agents are first-class when:

1. **`core/bin`** is on **`PATH`** (typically via **`postinstall`** or documented shell config), and  
2. **`dispatch-agent`** runs from that tree, sets **`PI_CODING_AGENT_DIR`** to **`…/agents/<name>`**, sets **`--session-dir`** to **`$DOT_PI_OVERLAY/<name>/sessions`**, and exports **`DOT_PI_OVERLAY`** (default **`~/.pi/dot-pi`**).

### 3.1 Repository development vs `pi install`

**Contributors** edit this repository with a normal **`git clone`** of the source and run tests locally; that checkout is **not** a second “supported install” for end users and is unrelated to **`pi update`**. Put the clone’s **`core/bin`** first on **`PATH`** after **`npm install`** in the clone so **`DOT_PI_DIR`** resolves to that tree (see **Local development** in **`README.md`**). **Consumers** rely solely on **`pi install`** / **`pi update`** against the published git (or npm) package.

### 3.2 `dispatch-agent` and “copy over”

Pi does **not** copy **`dispatch-agent`** into a second home by default. If you need files outside the clone (e.g. **`PATH`** shims in **`~/bin`**), implement that in **`package.json` scripts** (§2.3) or document a manual step.

### 3.3 User overlay directory (survives `pi update`)

Git package **`pi update`** runs **`git reset --hard`** and **`git clean -fdx`** in the Pi-managed clone when the installed git package changes. Anything that must **never** be wiped lives under **`~/.pi/dot-pi/`** (or **`$DOT_PI_OVERLAY`** if set), including **sessions**, user prompts/skills/extensions/themes, **`.service-name.env`** API keys, **`.tts-wpm`**, **`model-defaults`**, **`.model`** overrides, and dot-pi–scoped **`.ssh`** material.

**Convention:** **`DOT_PI_OVERLAY`** defaults to **`$HOME/.pi/dot-pi`** when unset. **`dispatch-agent`** and **`postinstall`** ensure **`$DOT_PI_OVERLAY/<agent>/sessions`** and sibling dirs exist. Per-agent overlay layout:

```text
$DOT_PI_OVERLAY/<agent>/
├── sessions/          # dispatch-agent --session-dir target
├── prompts/           # optional user slash-command templates
├── skills/            # optional user SKILL trees
├── extensions/        # optional user extensions
└── themes/            # optional user themes
```

Root-level **`$DOT_PI_OVERLAY/.exa.env`**, **`.tavily.env`**, **`.ntfy.env`**, **`.tts-wpm`**, and **`model-defaults`** remain the convention for shared local state. Clone-root fallbacks may exist for development checkouts, but product installs should resolve **`$DOT_PI_OVERLAY`** first.

### 3.4 Two-layer per-agent model (clone + overlay) and symlinks

**Shipped (“vanilla dot-pi”) per-agent tree** lives under the Pi-managed clone:

**`~/.pi/agent/git/<host>/<org>/dot-pi/agents/<agent>/{extensions,skills,prompts,themes}`**

That tree is **tracked in git**: shipped files plus **symlinks** into **`shared/`** (extension bundles, shared skills/themes, etc.). Pi discovers resources under **`PI_CODING_AGENT_DIR`** from this layout.

**User-owned per-agent content** lives under the overlay:

**`~/.pi/dot-pi/<agent>/{extensions,skills,prompts,themes}`**

It is **additive** by default: users add only what they need; shipped entries in the clone remain unless the user intentionally **shadows** the same leaf name (e.g. same skill id or prompt filename) by wiring a symlink or file in the agent tree that takes precedence—ordinary filesystem / discovery rules apply.

**Wiring overlay into Pi’s view** uses **symlinks from the clone’s `agents/<agent>/…` into `$DOT_PI_OVERLAY/<agent>/…`**, so **`PI_CODING_AGENT_DIR`** stays **`…/agents/<agent>`** and discovery stays unified. Symlink granularity matters because Pi’s auto-discovery is not uniformly recursive:

- **Prompts** — Pi discovers Markdown files directly under **`prompts/`**. Link individual prompt files (or use explicit settings entries/globs for user prompts if the project chooses that policy).
- **Themes** — Pi discovers JSON files directly under **`themes/`**. Link individual theme files.
- **Extensions** — Pi discovers extension files or one extension directory at a time. Link individual extension files/directories; do not rely on one parent symlink that contains many extension directories.
- **Skills** — Pi recursively discovers skill entries, so a linked skill directory can work, but precedence and collisions should still be deterministic.

**`git clean -fdx`** removes **untracked** symlinks in the clone, so **`postinstall`** must **recreate** overlay links on every **`pi install` / `pi update`**. If users add overlay content after install, support either a small relink command or explicit documentation for re-running the postinstall linker. Do not require the old broad **`dotpi sync`** behavior for correctness.

**No `dotpi sync` merge:** nothing in this model requires merging shipped resource inventory into **`settings.json`** arrays. Optional **`settings.json`** keys remain for Pi prefs and narrow user overrides only.

**Extensions and scripts** that read **`.exa.env`**, **`.tts-wpm`**, **`model-defaults`**, **`.model`**, etc., resolve **`$DOT_PI_OVERLAY`** first, then clone-local paths only as development fallbacks.

**`auth.json` / `models.json`:** keep using **`~/.pi/agent/auth.json`** and **`~/.pi/agent/models.json`** (symlinked from **`agents/<name>/`** in-repo if desired) so credentials and providers stay Pi-standard.

### 3.5 `settings.json` role (prefs, not dot-pi self-registration)

Each **`agents/<name>/settings.json`** (or a **symlink** from each agent dir to **`$DOT_PI_OVERLAY/settings.json`**) should hold **Pi-facing preferences**: theme, default model settings, feature flags, and similar runtime preferences. It must **not** list dot-pi itself in **`packages[]`**, because that would make Pi install or resolve a nested dot-pi clone under that runtime agent dir. It should also not be the primary source of truth listing every shipped extension, skill, prompt, and theme path—that remains **symlinks + dirs** under **`agents/<name>/`** as described in §3.4.

---

## 4. Vanilla `pi` vs `coder` / `mas`

### 4.1 Same binary

There is a **single** `pi` executable. Isolation is by **environment and paths**:

- **Vanilla** — **`PI_CODING_AGENT_DIR` unset** → Pi uses **`~/.pi/agent`** and **`~/.pi/agent/settings.json`**. That file may contain dot-pi’s package entry so **`pi update`** works. Vanilla sessions stay behaviorally clean because dot-pi’s package-root manifest exposes no resources to vanilla package loading.

- **Dot-pi agents** — **`PI_CODING_AGENT_DIR=<package-root>/agents/coder`** (etc.) → Pi uses that directory’s **`settings.json`**, **`SYSTEM.md`**, **`pi-args`**, and **auto-discovery** under **`agents/<name>/`** (extensions/skills/prompts/themes via symlinks as in §3.4). Runtime agent dirs do not rely on dot-pi self-registration in **`packages[]`**.

### 4.2 How users invoke names on `PATH`

**`core/bin/<name>`** symlinks to **`dispatch-agent`**, which resolves **`agents/<name>/`** and runs **`pi`** with **`PI_CODING_AGENT_DIR`** set ([`core/dispatch/main.sh`](core/dispatch/main.sh), [`core/dispatch/invoke.sh`](core/dispatch/invoke.sh)).

**`dispatch-agent`** centralizes **`pi-args`**, **`--session-dir`**, help, **`model-defaults`** loading (from **`$DOT_PI_OVERLAY`** or shipped fallback), and **`DOT_PI_OVERLAY`**. **Workspace-only behavior** (**`WORKSPACE_AGENT`**, dated **`workspaces/`**, **`bootstrap.sh`** workspace mode) is **removed** from the target product.

### 4.3 `packages` registration (vanilla settings, inert package)

**One** **`pi install`** run appends to **one** `settings.json` — the **`PI_CODING_AGENT_DIR`** in effect at install time.

The target product flow leaves **`PI_CODING_AGENT_DIR`** unset:

```bash
pi install git:https://github.com/<org>/dot-pi
```

That stores dot-pi’s package source in **`~/.pi/agent/settings.json`** and installs the clone under **`~/.pi/agent/git/<host>/<path>/`**. Ordinary **`pi update`** then updates dot-pi without a special wrapper or environment variable.

The key policy is that dot-pi’s root package manifest is inert for vanilla resource loading. Do **not** copy this package source into **`agents/<name>/settings.json`**. Those runtime settings files are preferences only; dot-pi named agents load resources from their filesystem trees.

---

## 5. Alternatives considered (and why `pi install` still helps)

| Approach | Pros | Cons |
|----------|------|------|
| **Symlink-only `shared/`** (status quo) | Simple; one checkout. | No **`pi update`** for the **installed** Pi package story; upgrades = manual **`git pull`** in a dev checkout only. |
| **Vanilla `pi install` git package** (target) | Minimal user story: ordinary **`pi install`**, ordinary **`pi update`**, Pi update notifications work. | Requires the root package manifest to stay inert so vanilla **`pi`** does not load dot-pi resources. |
| **Dedicated install agent dir** | Keeps dot-pi out of **`~/.pi/agent/settings.json`** entirely. | Less minimal: updates require **`PI_CODING_AGENT_DIR=<install-dir> pi update`** or a wrapper, and the clone lands under that install dir. |
| **`dotpi sync` merge after update** | Historically rebuilt symlink farms. | Deprecated; **`postinstall`** and a narrow relink command replace **consumer** reliance on broad **`dotpi sync`** for wiring after **`git clean`**. |
| **Workspace agents** | Isolated dated dirs per run. | Removed; **`--session-dir`** under **`~/.pi/dot-pi/<agent>/sessions`** gives durable sessions without a second cwd discipline. |
| **npm publish `@you/dot-pi`** | Same as git from Pi’s POV with `npm:`. | Publishing overhead. |

Dot-pi’s direction: **named agents first-class** from the **Pi-managed package tree**; **`package.json` + `pi install` + `pi update`** as the **only** supported install/upgrade path for users; an inert root package manifest so vanilla **`pi`** stays behaviorally clean; **`postinstall`** for **`PATH`**, overlay skeleton dirs, shared config links, and **symlink rewiring** into **`$DOT_PI_OVERLAY`**; **symlink-defined `agents/<name>/` trees** for skills/extensions/prompts/themes; runtime **`settings.json`** for prefs only, not dot-pi self-registration or shipped resource inventory; **`DOT_PI_OVERLAY`** for **durable per-agent sessions and user content**; **no broad `dotpi sync`**; **no workspace mode**; **removal** of the **curl `install`** flow from the supported repo surface.

---

## 6. Updates and notifications

### 6.1 User action

**Pushes to `main` do not change local disks** until the user runs **`pi update`** (or a targeted update). **`pi install`** only registers a source and materializes the tree; ongoing movement is handled by **`pi update`**.

### 6.2 “Pi knows” something moved

In **interactive** Pi, startup runs **`checkForAvailableUpdates()`** asynchronously; if updates exist, the UI shows **“Package Updates Available”** and suggests running **`pi update`**, listing display names (see pi-mono `interactive-mode.ts`).

**Caveats:**

- **`PI_OFFLINE`** — if set in the environment, Pi skips package update checks (and other network-sensitive package-manager paths) entirely.
- **Dispatch** — **`dispatch-agent` must not set `PI_OFFLINE=1`** so package update UI and **`pi install` / `pi update`** behave like bare **`pi`** for dispatched agents.
- **Pinned git refs** — may skip auto-update checks per Pi’s rules.
- **Non-interactive modes** — may not show the same UI nudge.

---

## 7. Relationship to existing dot-pi docs and scripts

- **[`install`](install)** — **Unsupported** under this plan: the **curl-to-bash** installer will be **removed** (or reduced to a short message pointing at **`pi install`**). **[`docs/install.md`](docs/install.md)** should describe **`pi install` / `pi update`** only.

- **[`core/commands/sync.sh`](core/commands/sync.sh)** — **Deprecated.** **`postinstall`** (and tracked in-repo symlinks where portable) replaces broad **`dotpi sync`** for **consumer** machines: **`core/bin`** on **`PATH`**, **`agents/<agent>/` → `shared/`** bundles as shipped, shared **`auth.json`** / **`models.json`** links to Pi-standard files, and **clone → overlay** symlinks recreated after **`git clean`**. **`agents/<name>/settings.json` must not symlink to `~/.pi/agent/settings.json`** if that vanilla file contains dot-pi’s package registration; runtime agent settings must not inherit dot-pi self-registration.

- **`dotpi doctor`** — **Deprecated** (was coupled to sync-era assumptions).

- **`AGENTS.md`** — Should be updated so **`DOT_PI_OVERLAY`**, **`~/.pi/dot-pi/<agent>/sessions`**, **two-layer clone + overlay symlink model**, and deprecation of **workspace agents** / **`dotpi sync`** match this document.

---

## 8. Checklist for maintainers shipping this

1. **Add** root **`package.json`** with an omitted or inert **`"pi"`** manifest and **`scripts.postinstall`**. The package may be registered in vanilla **`~/.pi/agent/settings.json`**, but it must expose no dot-pi resources to vanilla package loading.

2. **Document** the normal install/update flow: **`pi install git:https://github.com/<org>/dot-pi`** and **`pi update`**. Do not document a bootstrap agent dir as the target product path.

3. **Keep symlink-first `agents/<name>/` trees** into **`shared/`**; document **`postinstall`** rules for **overlay** symlinks; use runtime **`settings.json`** for Pi prefs only, not dot-pi self-registration and not full agent inventory in JSON arrays.

4. **`postinstall`** — Put **`core/bin`** on **`PATH`** or print exact shell instructions; create **`$DOT_PI_OVERLAY/<agent>/{sessions,prompts,skills,extensions,themes}`**; recreate shared **`auth.json`** / **`models.json`** links; create non-vanilla runtime **`settings.json`** files or links; and wire overlay content at Pi’s discovery granularity (prompt/theme files, extension dirs/files, skill dirs).

5. **`dispatch-agent`** — Export **`DOT_PI_OVERLAY`** (default **`~/.pi/dot-pi`**); pass **`--session-dir`** to an overlay location (prefer a per-cwd subtree if preserving current list/resume behavior matters); remove workspace **`bootstrap.sh`** / **`WORKSPACE_AGENT`** flows and dated **`workspaces/`** trees.

6. **Remove or narrow** **`dotpi sync`** and **`dotpi doctor`** from **`dotpi`** CLI and docs. If user-added overlay content needs relinking after install, keep a small relink command with a narrower contract and do not position it as a required periodic sync.

7. **Document** in **[`docs/install.md`](docs/install.md)** and **this file**: normal install, **`PATH`**, **`DOT_PI_OVERLAY`**, two-layer model, session locations, inert root package manifest, and no workspaces.

8. **Remove** the root **[`install`](install)** curl script (or replace with a pointer to **`pi install`**).

9. **Migrate mutable local state** out of the Pi-managed clone. Extensions and scripts should resolve **`$DOT_PI_OVERLAY`** first for **`.exa.env`**, **`.tavily.env`**, **`.ntfy.env`**, **`.tts-wpm`**, **`model-defaults`**, and **`.model`** overrides. Clone-local fallbacks are only for development checkouts.

---

## 9. Summary

| Question | Answer |
|----------|--------|
| What is **`packages`**? | A **`settings.json`** list of **installable sources** (git/npm/local) Pi uses to register and merge packages. For dot-pi, vanilla **`~/.pi/agent/settings.json`** contains the package entry so ordinary **`pi update`** works. Runtime **`agents/<name>/settings.json`** files must not list dot-pi itself. |
| Where does shipped per-agent config live? | **`~/.pi/agent/git/<host>/<org>/dot-pi/agents/<agent>/{extensions,skills,prompts,themes}`** — tracked clone + **symlinks** into **`shared/`**. |
| Where does user per-agent content live? | **`~/.pi/dot-pi/<agent>/{extensions,skills,prompts,themes}`** — **additive** by default; wired into Pi via **symlinks from the clone** maintained by **`postinstall`**. |
| Where does git install land? | Under **`~/.pi/agent/git/<host>/<path>/`** (default). Holds **`dispatch-agent`**, **`agents/`**, **`core/bin/`**. |
| How do users install dot-pi? | **`pi install`** (git or npm); **`pi update`** for upgrades. **No** curl **`install`**. **No `dotpi sync`**. |
| How do **`coder` / `mas`** work? | **`PI_CODING_AGENT_DIR`** → **`agents/<name>/`** via **`dispatch-agent`** + **`core/bin`** on **`PATH`**; **`--session-dir`** → **`~/.pi/dot-pi/<name>/sessions`**. |
| Workspaces? | **Removed** from target architecture. |
| How does vanilla **`pi`** stay vanilla? | **`~/.pi/agent/settings.json`** may contain dot-pi’s package entry, but dot-pi’s root package manifest is inert, so vanilla **`pi`** loads no dot-pi extensions, skills, prompts, or themes. |

This document should stay aligned with implementation as **`PI_INSTALL`-related** changes land in the repo.
