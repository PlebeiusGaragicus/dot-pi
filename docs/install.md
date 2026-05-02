# Installation & Setup

## One-liner install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

The installer will:

1. Check for required tools (`git`, `curl`, `jq`)
2. Offer to install `pi` via npm if not already present
3. Clone dot-pi to `~/.dot-pi`
4. Bootstrap local config files (`shared/settings.json`, `shared/auth.json`, `model-defaults`)
5. Build `bin/` symlinks and per-agent `auth.json` links (`dotpi sync`) so agent commands are on your PATH

Override the install location with `DOT_PI_HOME`:

```bash
DOT_PI_HOME=~/my-agents bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

## Requirements

- [pi](https://github.com/PlebeiusGaragicus/pi-mono) installed and on your `PATH` (the installer can do this)
- bash or zsh
- git, curl, jq

## Shell setup

The installer prints the two lines to add to your shell config. If you installed manually, add to your `~/.zshrc` or `~/.bashrc`:

```bash
export PATH="$HOME/.dot-pi/bin:$PATH"
source "$HOME/.dot-pi/env.sh"
```

Then reload your shell:

```bash
source ~/.zshrc  # or source ~/.bashrc
```

This puts all MAS and standalone agent commands on your PATH (e.g. `deepresearch`, `ask`, `web`).

`DOT_PI_DIR` is auto-detected from `env.sh`'s location, so the repo can live anywhere.

## Provider setup (`dotpi setup`)

Run `dotpi setup` to configure where your models come from. The wizard supports multiple providers — re-run anytime to add, edit, or remove one.

### Presets

The wizard offers quick presets for common setups:

| Preset | URL | Use case |
|--------|-----|----------|
| Ollama | `http://localhost:11434` | Local models on your own machine |
| LM Studio | `http://localhost:1234` | Local models via LM Studio |
| Custom OpenAI-compatible | (you provide) | Any OpenAI-API-compatible endpoint |
| Custom Anthropic-compatible | (you provide) | Anthropic-style endpoints |

For each provider, the wizard fetches available models (with an Ollama `/api/tags` fallback), lets you pick which to include, and saves them to `~/.pi/agent/models.json` (pi's system config). dot-pi symlinks `shared/models.json` to this file so all agent configs share the same provider configuration as bare `pi`.

**API credentials** for pi providers live in **`shared/auth.json`** (gitignored). `install` and `dotpi sync` bootstrap it from `bootstrap/auth.json.example` if missing, then symlink each top-level `agents/<name>/auth.json` → `shared/auth.json`. Edit that single file, or use `/login` in any agent so updates flow through the same path.

### Model defaults

After configuring providers, the wizard lets you assign local fallback models:

- `DEFAULT_AGENTIC_MODEL` — primary agent model fallback
- `DEFAULT_FAST_MODEL` — quick/cheap model fallback
- `DEFAULT_VLM_MODEL` — vision model fallback

These are exported from local `model-defaults` and can be overridden per-agent by a raw `agents/<name>/.model` value via `/model-default`. Each agent chooses which fallback to use in `pi-args`, for example `--model $DEFAULT_FAST_MODEL`. Empty defaults are valid; `dispatch-agent` skips empty `--model` values so pi uses its `settings.json` default.

### First-party auth

Use `/login` inside any agent session; credentials are stored in **`shared/auth.json`** (reachable via each agent’s `auth.json` symlink).

You normally **do not** need `dotpi link-auth` — **`dotpi sync`** points every top-level agent at **`shared/auth.json`**. Use `link-auth` only for overrides, for example:

```bash
dotpi link-auth shared recon
dotpi link-auth lm recon
```

### Multi-provider

`~/.pi/agent/models.json` supports multiple providers side-by-side. Each `dotpi setup` run adds or edits one provider without disturbing others. The default picker shows models from all providers. dot-pi's `shared/models.json` is a symlink to this system file — there is only one copy. Likewise, **`shared/auth.json`** is the single local credential store symlinked into each top-level agent config.

## Local one-device setup

For a fully local setup (no API keys needed):

1. Install [Ollama](https://ollama.com) and pull a model: `ollama pull llama3.2`
2. Run `dotpi setup`, pick the **Ollama** preset, accept defaults
3. Assign model defaults, then `lm` to start chatting

## Manual install

```bash
git clone https://github.com/PlebeiusGaragicus/dot-pi.git ~/.dot-pi
echo 'export PATH="$HOME/.dot-pi/bin:$PATH"' >> ~/.zshrc
echo 'source "$HOME/.dot-pi/env.sh"' >> ~/.zshrc
export PATH="$HOME/.dot-pi/bin:$PATH"
source "$HOME/.dot-pi/env.sh"
dotpi setup
```

## Verify

Check that your agent configs are set up and extensions are linked:

```bash
dotpi list
```

You should see each MAS with its subagent/prompt counts and orchestrator extension status, followed by any standalone agents.

Test a MAS:

```bash
cd /any/project
recon "What does this project do?"
```

## Update

Re-running the installer on an existing install shows an "already installed" message. To pull upstream changes while preserving local edits:

```bash
~/.dot-pi/install --force-rebase
```

## Uninstall

```bash
~/.dot-pi/install --uninstall
```

The uninstaller removes `~/.dot-pi` and attempts to clean dot-pi lines from your shell rc file. If it can't write to the rc file (e.g. permissions), it will show the lines to remove manually. Your system `~/.pi/agent/` directory (including `models.json` and `auth.json`) is not touched. If you keep credentials only under dot-pi's `shared/auth.json`, back it up before uninstall if needed.

---

## The `dotpi` CLI

`dotpi` manages agent config directories. It handles setup, scaffolding, listing, **`shared/auth.json`** wiring via **`dotpi sync`**, and optional **`dotpi link-auth`** overrides.

### `dotpi setup`

Interactive wizard that configures model providers, fetches available models, and then walks through `model-defaults`. Supports multiple providers (Ollama, LM Studio, custom endpoints). Re-run anytime to add, edit, or remove providers.

### `dotpi model-defaults`

Interactive picker for repo-local fallback model aliases in `model-defaults`. Re-run anytime after changing providers or model preferences.

### `/model-default`

Interactive in-agent command for local overrides. With no args, it opens a menu and offers to set the current agent's raw `.model` override when possible. Current-agent choices write one `provider/model` value to the agent config root's `.model`; global choices update repo-root `model-defaults`. Inline env overrides such as `DEFAULT_AGENTIC_MODEL=provider/model deepresearch` still win over both files.

### `dotpi create <mas-name>`

Creates a new MAS directory at `agents/<mas-name>/` with shared extension symlinks, theme symlinks, the `agent-orchestrator` extension, and a starter `SYSTEM.md`. Use `--workspace` to scaffold a `bootstrap.sh` that marks the MAS as a workspace agent.

After creating a MAS, you need to:

1. **Add subagents** -- add or link subagent config directories under `agents/<mas-name>/agents/`. Each subagent should have `SYSTEM.md` or `APPEND_SYSTEM.md`, and can include `USAGE.md` plus subagent-specific `pi-args`.
2. **Edit the orchestrator** -- update `agents/<mas-name>/SYSTEM.md` with the workflow and delegation policy.
3. **Add prompts** (optional) -- create `.md` files in `agents/<mas-name>/prompts/` for reusable workflows.
4. **Rebuild symlinks** -- run `dotpi sync` so the new MAS is available as a command.

### `dotpi create-agent <agent-name>`

Creates a standalone agent directory at `agents/<agent-name>/` with a stub extension and shared symlinks. Use `--workspace` to scaffold a `bootstrap.sh` that marks the agent as a workspace agent. Run `dotpi sync` to add the new agent to bin/.

### `dotpi list`

Shows all MAS and standalone agents with their counts and status.

### `dotpi link-skill <agent> <skill> [<skill> ...]`

Symlink shared skills into an agent config's `skills/` folder.

### `dotpi link-auth <source> <destination>`

Override **`auth.json`** with a symlink to another agent’s file, **`shared/auth.json`** (`dotpi link-auth shared <agent>`), or an explicit path. The default layout uses **`dotpi sync`** so every top-level agent points at **`shared/auth.json`** — only use `link-auth` for exceptions.

### `dotpi sync`

Rebuild `bin/` symlinks from `agents/`, bootstrap **`shared/auth.json`** from the example if missing, and link each **`agents/<name>/auth.json`** → **`shared/auth.json`**. Called automatically after `dotpi create` / `create-agent`.
