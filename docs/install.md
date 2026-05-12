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

**Contributors** developing from a git clone (without reinstalling through Pi on every change): see **Local development** in the repository [README](https://github.com/PlebeiusGaragicus/dot-pi#local-development) on GitHub, or the same section in a checkout’s `README.md`.

## What Install Does

Pi clones this repository under `~/.pi/agent/git/...` and runs `npm install`, which triggers dot-pi's `postinstall` script. The script is idempotent and safe to run after every `pi update`.

It creates or repairs clone-local symlinks, creates missing overlay directories, and prints **PATH** status (or a one-line `dotpi symlink-agents` command). It does not overwrite user-owned overlay files.

## Overlay State

Mutable dot-pi state lives outside the Pi-managed clone:

```text
$DOT_PI_OVERLAY/
├── settings.json
├── model-defaults
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

### Permission denied on `~/.zshrc` or `~/.bashrc`

If **`dotpi symlink-agents`** prints **`cannot write`** / **`touch: … Permission denied`**, your rc file is probably **not owned by your user** (often **`root`**) because something edited it with **`sudo`** once.

Check:

```bash
ls -la ~/.zshrc ~/.bashrc 2>/dev/null
```

If you see `root` as the owner, fix it **once**, then rerun **`dotpi symlink-agents`** (without sudo):

```bash
sudo chown "$(whoami)" ~/.zshrc
# and/or
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

Global model aliases are stored at:

```text
$DOT_PI_OVERLAY/model-defaults
```

Configure them with:

```bash
dotpi model-defaults
```

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
