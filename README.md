# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent configs as a Pi-installable package.

## Quick Start

```bash
pi install git:https://github.com/PlebeiusGaragicus/dot-pi
```

After install, if postinstall reports that agent commands are not on your `PATH`, run the printed command (usually `"<package>/core/bin/dotpi" symlink-agents`) or from any directory where `dotpi` resolves to this tree:

```bash
dotpi symlink-agents
```

That appends an idempotent block to `~/.zshrc` or `~/.bashrc` (from `$SHELL`). Then run any shipped agent command from a project directory:

```bash
ask -p "What does this project do?"
```

Updates use ordinary Pi package management:

```bash
pi update
```

Remove with the source shown by `pi list`:

```bash
pi remove git:https://github.com/PlebeiusGaragicus/dot-pi
```

Mutable user state lives under `$DOT_PI_OVERLAY` (default `~/.pi/dot-pi`) so `pi update` can reset and clean the package clone without touching sessions, model defaults, API-key env files, prompts, skills, extensions, themes, or shared dot-pi `settings.json`.

## Shell Integration

Commands are available through symlinks in the installed package's `core/bin/`. If you add or remove local overlay resources manually, run:

```bash
dotpi relink
```

## Local development

You can iterate on this repository from a normal **`git clone`** without running **`pi update`** after every edit. The dispatcher sets **`DOT_PI_DIR`** from the resolved path of **`dispatch-agent`**, so whichever clone’s **`core/bin`** is **first on your `PATH`** is the tree Pi loads (`agents/<name>/`, `shared/`, extensions, and so on).

1. Clone the repo to any directory and **`cd`** into it.
2. Run **`npm install`** in the repo root so **`postinstall`** runs (symlinks, overlay wiring—same as after **`pi install`**).
3. **Prepend** this clone’s **`core/bin`** to **`PATH`** (before any Pi-installed dot-pi **`core/bin`** if you have both), or run **`./dotpi symlink-agents --rc ~/.zshrc`** (or **`~/.bashrc`**) once so your shell rc picks up this clone.
4. Run **`ask`**, **`mas`**, **`dotpi`**, etc. as usual. You still need a working **`pi`** binary and the usual **`~/.pi/agent`** auth and model files.

Optional TypeScript check for shared extensions:

```bash
(cd core/tests && npx tsc --noEmit)
```

The supported **consumer** flow remains **`pi install`** / **`pi update`** as in [Quick Start](#quick-start). See **`PI_INSTALL.md`** in this repo for architecture notes (including how this differs from the Pi-managed package tree).

## Create Agents

```bash
dotpi create my-research-mas
dotpi create-agent my-agent
```

Both create in-situ agents. Workspace mode has been removed; sessions are stored under `$DOT_PI_OVERLAY/<agent>/sessions/`.

## Docs

See the [documentation site](https://PlebeiusGaragicus.github.io/dot-pi/) for installation, usage, extension API, and MAS details.
