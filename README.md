# dot-pi

Custom [pi](https://github.com/PlebeiusGaragicus/pi-mono) agent teams as dotfiles.

Manage multiple pi coding agent configurations without touching `~/.pi/`. Each team or standalone agent gets its own isolated directory with extensions, agents, prompts, skills, and session history. A shell function sets `PI_CODING_AGENT_DIR` and you're running a fully isolated agent from any working directory.

## Quick Start

```bash
git clone git@github.com:PlebeiusGaragicus/dot-pi.git ~/dot-pi
cd ~/dot-pi && git submodule update --init

cp example.env .env
# Edit .env with your API keys

echo 'source ~/dot-pi/bash_aliases' >> ~/.zshrc
source ~/dot-pi/bash_aliases
```

### Zsh tab completion for `p`

When you use zsh, `bash_aliases` sources [p-completion.zsh](p-completion.zsh) at the end (skipped when the same file is sourced from bash). Put `autoload -Uz compinit && compinit` **before** `source …/bash_aliases` in `~/.zshrc` so `compdef` is available.

`p b` + Tab completes to real directory names such as `blog` (case-insensitive matching; inserted text matches on-disk spelling). A bare `p ` + Tab does nothing so it does not duplicate the list from running `p` alone.

## Create a Team

```bash
./setup.sh create my-team
# Add agents to teams/my-team/agents/
# Add prompts to teams/my-team/prompts/
```

## Docs

See the [documentation site](https://PlebeiusGaragicus.github.io/dot-pi/) for architecture, usage, extension API, and per-team details.
