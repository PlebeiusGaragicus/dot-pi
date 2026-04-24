# Installation & Setup

## One-liner install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

The installer will:

1. Check for required tools (`git`, `curl`, `jq`)
2. Offer to install `pi` via npm if not already present
3. Clone dot-pi to `~/.dot-pi`
4. Bootstrap local config files (`shared/settings.json`, `model_roles`)
5. Build `bin/` symlinks so agent commands are on your PATH

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

This puts all team and standalone agent commands on your PATH (e.g. `recon`, `blog`, `lm`).

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

For each provider, the wizard fetches available models (with an Ollama `/api/tags` fallback), lets you pick which to include, and saves them to `shared/models.json`.

### Model roles

After configuring providers, the wizard lets you assign a default model to each role:

- `AGENTIC_MODEL` — primary agent model
- `THINKING_MODEL` — reasoning-heavy tasks
- `CODING_MODEL` — code generation
- `VISION_MODEL` — image understanding
- `FAST_MODEL` — quick/cheap completions

These are exported as env vars via `model_roles` (sourced by `env.sh`) and can be referenced in `pi-args` files. All roles are optional.

### First-party auth

For pi's built-in providers, use `/login` inside any agent session. Share that auth across teams with `dotpi link-auth`:

```bash
lm                          # start a session, use /login to authenticate
dotpi link-auth lm recon    # share auth.json from lm to recon
```

### Multi-provider

`shared/models.json` supports multiple providers side-by-side. Each `dotpi setup` run adds or edits one provider without disturbing others. The role picker shows models from all providers.

## Local one-device setup

For a fully local setup (no API keys needed):

1. Install [Ollama](https://ollama.com) and pull a model: `ollama pull llama3.2`
2. Run `dotpi setup`, pick the **Ollama** preset, accept defaults
3. Assign roles, then `lm` to start chatting

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

Check that your teams are set up and extensions are linked:

```bash
dotpi list
```

You should see each team with its agent/prompt counts and extension link status, followed by any standalone agents.

Test a team:

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

---

## The `dotpi` CLI

`dotpi` manages team and standalone agent directories. It handles setup, scaffolding, listing, and auth sharing.

### `dotpi setup`

Interactive wizard that configures model providers, fetches available models, and assigns model roles. Supports multiple providers (Ollama, LM Studio, custom endpoints). Re-run anytime to add, edit, or remove providers.

### `dotpi create <team-name>`

Creates a new team directory at `teams/<team-name>/` with shared extension symlinks, theme symlinks, and a starter `team-prompt.md`. Use `--workspace` for workspace mode.

After creating a team, you need to:

1. **Add agents** -- create `.md` files in `teams/<team-name>/agents/` with YAML frontmatter (`name`, `description`, optionally `tools`, `skills`, `no-skills`, `model`, `team`) and a system prompt body.
2. **Add prompts** (optional) -- create `.md` files in `teams/<team-name>/prompts/` that define chain/parallel workflows.
3. **Rebuild symlinks** -- run `dotpi sync` to rebuild bin/ symlinks so the new team is available as a command.

### `dotpi create-agent <agent-name>`

Creates a standalone agent directory at `agents/<agent-name>/` with a stub extension and shared symlinks. Use `--workspace` for workspace mode. Run `dotpi sync` to add the new agent to bin/.

### `dotpi list`

Shows all teams and standalone agents with their counts and status.

### `dotpi link-skill <team-or-agent> <skill> [<skill> ...]`

Symlink shared skills into a team or agent's `skills/` folder.

### `dotpi link-auth <source> <destination>`

Share `auth.json` from one team/agent to another via symlink. Useful after authenticating via `/login` in one agent.

### `dotpi sync`

Rebuild `bin/` symlinks from `agents/` and `teams/` directories. Called automatically after `dotpi create` / `create-agent`.
