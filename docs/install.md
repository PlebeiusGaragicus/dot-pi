# Installation & Setup

dot-pi is installed as a normal Pi git package. The supported user flow is:

```bash
pi install git:https://github.com/PlebeiusGaragicus/dot-pi
```

Then put the installed package's `core/bin` on your `PATH`. After `pi install` or `pi update`, **postinstall** checks whether agent commands from **this** install already resolve on your current `PATH`:

- If yes, it prints a short confirmation.
- If not, it prints a single command to run, for example:

```bash
"$HOME/.pi/agent/git/github.com/PlebeiusGaragicus/dot-pi/core/bin/dotpi" symlink-agents
```

That updates `~/.zshrc` or `~/.bashrc` (based on your `$SHELL`) with an **idempotent** `export PATH="…/core/bin:$PATH"` block. You can also run `dotpi symlink-agents` from a shell where `dotpi` already refers to this install.

Alternatively you can add the same `export PATH=…` line manually; the path is under `~/.pi/agent/git/.../core/bin` for git installs.

Use ordinary Pi updates:

```bash
pi update
```

Remove the package with the same source identity Pi records in `pi list`:

```bash
pi remove git:https://github.com/PlebeiusGaragicus/dot-pi
```

The old curl installer and `~/.dot-pi` product install are no longer supported.

**Maintainer note:** Pi **`packages[]`**, clone lifecycle, nested-clone pitfalls, and clone-vs-overlay wiring are summarized in [Architecture](architecture.md).

### Do not register dot-pi inside a worker agent

**Never** add the dot-pi git source to **`packages[]`** inside an **`agents/<name>/settings.json`** (or any runtime agent settings that Pi treats as an install root). Pi would try to clone dot-pi again under that agent directory. Package registration belongs in vanilla **`~/.pi/agent/settings.json`** for the supported install path.

**Contributors** developing from a git clone (without reinstalling through Pi on every change): see **Local development** in the repository [README](https://github.com/PlebeiusGaragicus/dot-pi#local-development) on GitHub, or the same section in a checkout’s `README.md`.

## What Install Does

Pi clones this repository under `~/.pi/agent/git/...` and runs `npm install`, which triggers dot-pi's `postinstall` script. The script is idempotent and safe to run after every `pi update`.

It creates or repairs clone-local symlinks, creates missing overlay directories, and prints **PATH** status (or a one-line `dotpi symlink-agents` command). It does not overwrite user-owned overlay files.

Unless skipped (see below), postinstall also installs JavaScript dependencies under `core/utilities/browser-runtime` and runs **Playwright’s** `install chromium` so the **browser-control** daemon has a matching Chromium build (the `playwright` npm package does not download browsers by itself).

To skip that step (CI, air-gapped machines, or when you manage browsers yourself), set **`PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1`** (Playwright’s own flag) or **`DOT_PI_SKIP_PLAYWRIGHT_INSTALL=1`**. If postinstall skipped or could not download browsers, install manually from the package clone:

```bash
cd /path/to/dot-pi/core/utilities/browser-runtime && bun install && bunx playwright install chromium
```

(Use `npm install` and `npx playwright install chromium` if you do not use Bun.)

## Overlay State

Mutable dot-pi state lives outside the Pi-managed clone:

```text
$DOT_PI_OVERLAY/
├── settings.json
├── env.exa
├── env.tavily
├── env.ntfy
├── env.tts-wpm
└── <agent>/
    ├── sessions/
    ├── prompts/
    ├── skills/
    ├── extensions/
    └── themes/
```

`DOT_PI_OVERLAY` defaults to:

```bash
$HOME/.pi/dot-pi
```

Install/update scripts may create missing directories and seed files, but they must not overwrite, truncate, replace, or delete existing overlay files. In particular, `$DOT_PI_OVERLAY/settings.json` is shared user-owned settings for dot-pi agents.

## PATH for agent commands

Use **`dotpi symlink-agents`** (or the full path printed by postinstall) so `ask`, `mas`, `coder`, etc. resolve in new terminals. Options: **`--dry-run`**, **`--rc FILE`** (e.g. fish users can target a file they maintain). Re-run after changing install location; the command refreshes the marked block.

On **Linux with bash**, `SHELL` is usually `/bin/bash` and dot-pi updates **`~/.bashrc`**. If you use a **login** shell that does not source `~/.bashrc` (some SSH or minimal setups), either run **`dotpi symlink-agents --rc ~/.bash_profile`** or add `if [ -f ~/.bashrc ]; then . ~/.bashrc; fi` to your **`~/.bash_profile`** so new sessions pick up the block.

### Permission denied on `~/.zshrc` or `~/.bashrc`

If **`dotpi symlink-agents`** prints **`cannot write`** / **`touch: … Permission denied`**, your rc file is probably **not owned by your user** (often **`root`**) because something edited it with **`sudo`** once.

Check:

```bash
ls -la ~/.zshrc ~/.bashrc 2>/dev/null
```

If you see `root` as the owner, fix it **once**, then rerun **`dotpi symlink-agents`** (without sudo):

```bash
sudo chown "$(whoami)" ~/.zshrc
# and/or (Linux/bash)
sudo chown "$(whoami)" ~/.bashrc
```

Do **not** run **`dotpi symlink-agents`** with **`sudo`** as a workaround; that can make ownership worse. The command prints **`ls -la`** and a copy-paste **`chown`** line when it detects a non-writable target.

## Agent Commands

Commands such as `coder`, `ask`, or `mas` are symlinks in `core/bin` that point to `dispatch-agent`. The symlink name selects `agents/<name>/`, sets `PI_CODING_AGENT_DIR`, reads that agent's `pi-args`, and runs `pi`.

Sessions are stored under the overlay, not the package clone:

```text
$DOT_PI_OVERLAY/<agent>/sessions/<current-working-directory-key>/
```

## Provider Setup

Run:

```bash
dotpi setup
```

Provider models are stored in Pi's standard `~/.pi/agent/models.json`. Credentials are stored in Pi's standard `~/.pi/agent/auth.json`. dot-pi exposes them through `$DOT_PI_OVERLAY/models.json` and `$DOT_PI_OVERLAY/auth.json`, then through `shared/models.json` and `shared/auth.json`, so all dot-pi agents share the same files as vanilla `pi`.

### LM Studio model catalog

If your models are served from **LM Studio** (local server or any OpenAI-compatible URL whose origin exposes LM Studio’s `GET /api/v1/models`), generate a provider entry with the bundled script. It reads each model’s reasoning `allowed_options` and emits a matching `thinkingLevelMap` where applicable.

**Script location**

- After install, `postinstall` prints the package root; the script is always `<dot-pi-root>/core/scripts/lmstudio-models`.
- Typical **Pi git install** path (adjust if you use a fork or different host/path):

```bash
"$HOME/.pi/agent/git/github.com/PlebeiusGaragicus/dot-pi/core/scripts/lmstudio-models"
```

**Run (interactive, recommended)** — With no flags, the script prompts on the terminal for LM Studio URL, API key (leave blank if unused), and provider name (default `lmstudio`). Progress goes to **stderr**; the catalog JSON goes to **stdout** only.

One-liner to write Pi’s catalog (adjust the script path if needed):

```bash
"$HOME/.pi/agent/git/github.com/PlebeiusGaragicus/dot-pi/core/scripts/lmstudio-models" > ~/.pi/agent/models.json
```

**Warning:** `>` **replaces the entire** `~/.pi/agent/models.json`. Use this when LM Studio is your only provider or you intend to replace the whole file. If you already have other providers, use the merge flow below instead of redirecting straight to `~/.pi/agent/models.json`.

**Run (non-interactive)** — For scripts or CI, pass flags (use a real key when the server requires `Authorization: Bearer`):

```bash
"$HOME/.pi/agent/git/github.com/PlebeiusGaragicus/dot-pi/core/scripts/lmstudio-models" \
  --url "http://localhost:1234" \
  --key "" \
  --name lmstudio
```

**Merge into `~/.pi/agent/models.json`**

To keep existing providers, write generated JSON to a temp file (prompts still work; only JSON is captured), then merge with `jq`:

```bash
GEN=/tmp/lmstudio-models-gen.json
"$HOME/.pi/agent/git/github.com/PlebeiusGaragicus/dot-pi/core/scripts/lmstudio-models" >"$GEN"
SYSTEM="$HOME/.pi/agent/models.json"
jq --slurpfile gen "$GEN" '.providers = (.providers // {}) * ($gen[0].providers)' "$SYSTEM" >"${SYSTEM}.tmp" && mv "${SYSTEM}.tmp" "$SYSTEM"
```

For a non-interactive merge, generate `$GEN` using the `--url`, `--key`, and `--name` flags instead.

If you pass `--key`, the printed JSON includes an `apiKey` field inside that provider — do not commit or share that output; redact before pasting into docs or tickets.

For other cloud providers and interactive editing, use **`dotpi setup`** as above.

## Repair Local Links

Normally `postinstall` runs automatically during `pi install` and `pi update`. If you add overlay prompts, skills, extensions, or themes manually and want dot-pi to relink them into the package clone, run:

```bash
dotpi relink
```

`dotpi relink` has the same narrow contract as postinstall: repair clone-local symlinks and create missing overlay directories without mutating existing overlay files.

## Verify

```bash
dotpi list
ask -p "say hello"
```

If `ask` is not found, run **`dotpi symlink-agents`** (see [PATH for agent commands](#path-for-agent-commands)) or add the printed `core/bin` path to your shell config and restart the shell.
