#!/usr/bin/env bash
set -euo pipefail

DOT_PI_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$DOT_PI_DIR/shared"

usage() {
  cat <<EOF
dot-pi manager

Usage: $(basename "$0") <command> [args]

Commands:
  create [--workspace] <team-name>         Create a new team directory with shared extension symlinks
  create-agent [--workspace] <agent-name>  Create a standalone agent directory with a stub extension
  list                                     List existing teams and standalone agents
  link-skill <team-or-agent> <skill> [...] Symlink one or more shared skills into a team or agent
  link-auth <src> <dst>                    Symlink auth.json from one team/agent (or path) into another

Options:
  --workspace   Mark as a workspace agent/team. Creates a workspace.conf file so the
                auto-generated alias launches pi in a fresh dated directory instead of
                the user's current directory. Edit workspace.conf to list subdirectories
                that should be pre-created in each workspace run.

Examples:
  $(basename "$0") create blog
  $(basename "$0") create --workspace deepresearch
  $(basename "$0") create-agent twenty-questions
  $(basename "$0") create-agent --workspace my-researcher
  $(basename "$0") list
  $(basename "$0") link-skill my-agent searxng
  $(basename "$0") link-auth recon blog
EOF
  exit 1
}

create_team() {
  local workspace=false
  if [ "$1" = "--workspace" ]; then
    workspace=true
    shift
  fi
  local team_name="$1"
  local team_dir="$DOT_PI_DIR/teams/$team_name"

  if [ -d "$team_dir" ]; then
    echo "Error: team '$team_name' already exists at $team_dir"
    exit 1
  fi

  echo "Creating team '$team_name'..."
  mkdir -p "$team_dir/extensions" "$team_dir/agents" "$team_dir/prompts" "$team_dir/skills" "$team_dir/sessions"

  # Symlink shared prompts (e.g. help.md) into the team's prompts/ directory.
  ln -sf "../../../shared/prompts/help.md" "$team_dir/prompts/help.md"

  # Symlink shared extensions into the team's extensions/ directory.
  # pi auto-discovers extensions from <agentDir>/extensions/.
  ln -sf "../../../shared/extensions/subagent-teams" "$team_dir/extensions/subagent-teams"
  ln -sf "../../../shared/extensions/run-finish-notify" "$team_dir/extensions/run-finish-notify"
  ln -sf "../../../shared/extensions/startup-branding" "$team_dir/extensions/startup-branding"

  # skills/ is created empty — add symlinks with: ./setup.sh link-skill <team-name> <skill>
  # pi auto-discovers skills from <agentDir>/skills/. Per-subagent control: frontmatter (skills, no-skills).

  # Symlink each shared theme individually into the team's themes/ directory.
  # pi auto-discovers themes from <agentDir>/themes/.
  mkdir -p "$team_dir/themes"
  for theme in "$SHARED_DIR"/themes/*.json; do
    [ -f "$theme" ] || continue
    ln -sf "../../../shared/themes/$(basename "$theme")" "$team_dir/themes/$(basename "$theme")"
  done

  # Symlink shared bin directory.
  # pi downloads fd/rg here on first run; the symlink means all teams share one copy.
  mkdir -p "$SHARED_DIR/bin"
  ln -sf "../../shared/bin" "$team_dir/bin"

  # Symlink shared model provider config
  ln -sf "../../shared/models.json" "$team_dir/models.json"

  # Scaffold default settings (theme + quiet startup)
  cat > "$team_dir/settings.json" <<'SETTINGS'
{
  "theme": "synthwave",
  "quietStartup": true
}
SETTINGS

  cat > "$team_dir/pi-args" <<'PIARGS'
# Optional default CLI flags for `p <name>` (read by bash_aliases). One flag per line; # starts a comment.
#
# IMPORTANT: must end with a newline (this comment also works) or last line will be ignored
PIARGS

  # Generate startup banner with figlet (soft fail if not installed)
  if command -v figlet &>/dev/null; then
    { figlet -f small "$team_name"; echo "---"; echo "Team: $team_name"; } > "$team_dir/banner.txt"
    echo "Generated banner.txt (edit to customize)"
  else
    echo "Warning: figlet not installed -- skipping banner.txt (brew install figlet)"
  fi

  # Scaffold default team-prompt.md with name/description/tools/model frontmatter
  cat > "$team_dir/team-prompt.md" <<TEAMPROMPT
---
name: $(echo "$team_name" | sed 's/./\U&/')
description: $team_name agent team.
# tools: read, grep, find, ls
# model: plebchat/qwen/qwen3-coder-next
---

# $team_name Team

You are the orchestrator for the $team_name team. Add your orchestrator prompt here.
TEAMPROMPT
  echo "Created team-prompt.md (edit to customize)"

  if [ "$workspace" = true ]; then
    cat > "$team_dir/workspace.conf" <<'WSCONF'
# Subdirectories to pre-create in each workspace run.
# One directory name per line. The alias reads this file
# and runs mkdir -p for each entry before launching pi.
#
# IMPORTANT: must end with a newline (this comment also works) or last line will be ignored
WSCONF
    echo "Created workspace.conf (edit to add workspace subdirectories)"
  fi

  local mode_label="in-situ"
  [ "$workspace" = true ] && mode_label="workspace"

  echo "Created $mode_label team at $team_dir"
  echo ""
  echo "Directory layout:"
  echo "  $team_dir/"
  echo "    extensions/          (symlinked to shared)"
  echo "    agents/              (add your agent .md files here)"
  echo "    prompts/             (add workflow prompt templates here)"
  echo "    skills/              (empty — use ./setup.sh link-skill $team_name <skill>)"
  echo "    themes/              (individual themes symlinked from shared)"
  echo "    bin/                 (symlinked to shared/bin, gitignored contents)"
  echo "    sessions/            (runtime session data, gitignored)"
  echo "    team-prompt.md       (orchestrator prompt with tools/model frontmatter)"
  echo "    banner.txt           (startup branding -- edit to customize)"
  echo "    models.json          (symlinked to shared)"
  echo "    settings.json        (theme + quietStartup defaults)"
  echo "    pi-args              (optional default CLI flags; see IMPORTANT line inside)"
  [ "$workspace" = true ] && echo "    workspace.conf       (workspace subdirectory list)"
  echo ""
  echo "Next steps:"
  echo "  1. Add agent .md files to $team_dir/agents/"
  echo "  2. Add prompt templates to $team_dir/prompts/"
  if [ "$workspace" = true ]; then
    echo "  3. Link skills as needed: ./setup.sh link-skill $team_name <skill>"
    echo "  4. Edit workspace.conf to list subdirectories for each run"
    echo "  5. Source bash_aliases and invoke: pi-$team_name \"your task\""
  else
    echo "  3. Link skills as needed: ./setup.sh link-skill $team_name <skill>"
    echo "  4. Source bash_aliases and invoke: pi-$team_name \"your task\""
  fi
}

create_agent() {
  local workspace=false
  if [ "$1" = "--workspace" ]; then
    workspace=true
    shift
  fi
  local agent_name="$1"
  local agent_dir="$DOT_PI_DIR/agents/$agent_name"

  if [ -d "$agent_dir" ]; then
    echo "Error: agent '$agent_name' already exists at $agent_dir"
    exit 1
  fi

  echo "Creating standalone agent '$agent_name'..."
  mkdir -p "$agent_dir/extensions/$agent_name" "$agent_dir/skills" "$agent_dir/sessions" "$agent_dir/prompts"

  # Symlink shared prompts (e.g. help.md) into the agent's prompts/ directory.
  ln -sf "../../../shared/prompts/help.md" "$agent_dir/prompts/help.md"

  # Symlink shared extensions (but NOT subagent-teams -- standalone agents don't need it).
  ln -sf "../../../shared/extensions/run-finish-notify" "$agent_dir/extensions/run-finish-notify"
  ln -sf "../../../shared/extensions/startup-branding" "$agent_dir/extensions/startup-branding"
  ln -sf "../../../shared/extensions/say" "$agent_dir/extensions/say"

  # Create a stub extension for the agent to customize
  cat > "$agent_dir/extensions/$agent_name/index.ts" <<'STUB'
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	// Add lifecycle hooks and custom tools here.
	// See docs/reference/extensions.md for the extension API.
}
STUB

  # skills/ is created empty — add symlinks with: ./setup.sh link-skill <agent-name> <skill>

  mkdir -p "$agent_dir/themes"
  for theme in "$SHARED_DIR"/themes/*.json; do
    [ -f "$theme" ] || continue
    ln -sf "../../../shared/themes/$(basename "$theme")" "$agent_dir/themes/$(basename "$theme")"
  done

  mkdir -p "$SHARED_DIR/bin"
  ln -sf "../../shared/bin" "$agent_dir/bin"

  ln -sf "../../shared/models.json" "$agent_dir/models.json"

  # Scaffold default settings (theme + quiet startup)
  cat > "$agent_dir/settings.json" <<'SETTINGS'
{
  "theme": "synthwave",
  "quietStartup": true
}
SETTINGS

  cat > "$agent_dir/pi-args" <<'PIARGS'
# Optional default CLI flags for `p <name>` (read by bash_aliases). One flag per line; # starts a comment.
#
# IMPORTANT: must end with a newline (this comment also works) or last line will be ignored
PIARGS

  cat > "$agent_dir/SYSTEM.md" <<SYSTEMMD
# Edit the body below. Pi loads this file as your system prompt (replaces the default).

You are a helpful assistant for the **$agent_name** agent. Describe your role, tone, and constraints here.
SYSTEMMD

  # Generate startup banner with figlet (soft fail if not installed)
  if command -v figlet &>/dev/null; then
    { figlet -f small "$agent_name"; echo "---"; echo "Agent: $agent_name"; } > "$agent_dir/banner.txt"
    echo "Generated banner.txt (edit to customize)"
  else
    echo "Warning: figlet not installed -- skipping banner.txt (brew install figlet)"
  fi

  if [ "$workspace" = true ]; then
    cat > "$agent_dir/workspace.conf" <<'WSCONF'
# Subdirectories to pre-create in each workspace run.
# One directory name per line. The alias reads this file
# and runs mkdir -p for each entry before launching pi.
#
# IMPORTANT: must end with a newline (this comment also works) or last line will be ignored
WSCONF
    echo "Created workspace.conf (edit to add workspace subdirectories)"
  fi

  local mode_label="in-situ"
  [ "$workspace" = true ] && mode_label="workspace"

  echo "Created $mode_label standalone agent at $agent_dir"
  echo ""
  echo "Directory layout:"
  echo "  $agent_dir/"
  echo "    extensions/              ($agent_name/, run-finish-notify, startup-branding, say.ts)"
    echo "    skills/                  (empty — use ./setup.sh link-skill $agent_name <skill>)"
  echo "    prompts/                 (shared help.md symlinked; add agent-specific prompts here)"
  echo "    themes/                  (individual themes symlinked from shared)"
  echo "    bin/                     (symlinked to shared/bin, gitignored contents)"
  echo "    sessions/                (runtime session data, gitignored)"
  echo "    models.json              (symlinked to shared)"
  echo "    settings.json            (theme + quietStartup defaults)"
  echo "    pi-args                  (optional default CLI flags; see IMPORTANT line inside)"
  echo "    SYSTEM.md                (system prompt — edit to customize)"
  echo "    banner.txt               (startup branding -- edit to customize)"
  [ "$workspace" = true ] && echo "    workspace.conf           (workspace subdirectory list)"
  echo ""
  echo "Next steps:"
  echo "  1. Edit $agent_dir/SYSTEM.md (and optionally pi-args)"
  echo "  2. Edit $agent_dir/extensions/$agent_name/index.ts if you need custom tools"
  echo "  3. Link skills as needed: ./setup.sh link-skill $agent_name <skill>"
  if [ "$workspace" = true ]; then
    echo "  4. Edit workspace.conf to list subdirectories for each run"
    echo "  5. Source bash_aliases and invoke: pi-$agent_name \"your task\""
  else
    echo "  4. Source bash_aliases and invoke: pi-$agent_name \"your task\""
  fi
}

list_teams() {
  local found=0

  echo "Teams:"
  for dir in "$DOT_PI_DIR"/teams/*/; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    found=1
    local agent_count
    agent_count=$(find "$dir/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    local prompt_count
    prompt_count=$(find "$dir/prompts" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    local mode="in-situ"
    [ -f "$dir/workspace.conf" ] && mode="workspace"
    local ext_ok="no"
    [ -e "$dir/extensions/subagent-teams/index.ts" ] && ext_ok="yes"
    echo "  $name  ($mode, $agent_count agents, $prompt_count prompts, extensions linked: $ext_ok)"
  done
  if [ "$found" -eq 0 ]; then
    echo "  (none -- run '$0 create <name>' to create one)"
  fi

  echo ""
  echo "Standalone agents:"
  local agent_found=0
  for dir in "$DOT_PI_DIR"/agents/*/; do
    [ -d "$dir" ] || continue
    local name
    name=$(basename "$dir")
    agent_found=1
    local mode="in-situ"
    [ -f "$dir/workspace.conf" ] && mode="workspace"
    local ext_count
    ext_count=$(find "$dir/extensions" -maxdepth 2 -name 'index.ts' 2>/dev/null | wc -l | tr -d ' ')
    echo "  $name  ($mode, extensions: $ext_count)"
  done
  if [ "$agent_found" -eq 0 ]; then
    echo "  (none -- run '$0 create-agent <name>' to create one)"
  fi
}

resolve_dir() {
  local name="$1"
  if [ -d "$DOT_PI_DIR/teams/$name" ]; then
    echo "$DOT_PI_DIR/teams/$name"
  elif [ -d "$DOT_PI_DIR/agents/$name" ]; then
    echo "$DOT_PI_DIR/agents/$name"
  else
    return 1
  fi
}

link_skill() {
  local target="$1"
  shift
  [ $# -lt 1 ] && {
    echo "Error: at least one skill name required"
    usage
  }

  local dst_dir
  dst_dir=$(resolve_dir "$target") || {
    echo "Error: '$target' does not exist as a team or agent"
    exit 1
  }

  mkdir -p "$dst_dir/skills"

  local name
  for name in "$@"; do
    local src="$SHARED_DIR/skills/$name"
    if [ ! -d "$src" ]; then
      echo "Error: no shared skill at $src"
      exit 1
    fi
    ln -sf "../../../shared/skills/$name" "$dst_dir/skills/$name"
    echo "Linked $dst_dir/skills/$name -> ../../../shared/skills/$name"
  done
}

link_auth() {
  local src="$1"
  local dst="$2"

  local src_path
  if [ -f "$src" ]; then
    src_path="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
  elif [ -f "$DOT_PI_DIR/teams/$src/auth.json" ]; then
    src_path="$DOT_PI_DIR/teams/$src/auth.json"
  elif [ -f "$DOT_PI_DIR/agents/$src/auth.json" ]; then
    src_path="$DOT_PI_DIR/agents/$src/auth.json"
  else
    echo "Error: cannot find auth.json at '$src' or in team/agent '$src'"
    exit 1
  fi

  local dst_dir
  dst_dir=$(resolve_dir "$dst") || {
    echo "Error: '$dst' does not exist as a team or agent"
    exit 1
  }

  ln -sf "$src_path" "$dst_dir/auth.json"
  echo "Linked $dst_dir/auth.json -> $src_path"
}

# ── main ─────────────────────────────────────────────────────────────────────

[ $# -lt 1 ] && usage

case "$1" in
  create)
    shift
    if [ "$1" = "--workspace" ]; then
      [ $# -lt 2 ] && { echo "Error: team name required"; usage; }
      create_team --workspace "$2"
    else
      [ $# -lt 1 ] && { echo "Error: team name required"; usage; }
      create_team "$1"
    fi
    ;;
  create-agent)
    shift
    if [ "$1" = "--workspace" ]; then
      [ $# -lt 2 ] && { echo "Error: agent name required"; usage; }
      create_agent --workspace "$2"
    else
      [ $# -lt 1 ] && { echo "Error: agent name required"; usage; }
      create_agent "$1"
    fi
    ;;
  list)
    list_teams
    ;;
  link-skill)
    [ $# -lt 3 ] && { echo "Error: team/agent name and at least one skill required"; usage; }
    shift
    link_skill "$@"
    ;;
  link-auth)
    [ $# -lt 3 ] && { echo "Error: source and destination required"; usage; }
    link_auth "$2" "$3"
    ;;
  *)
    echo "Error: unknown command '$1'"
    usage
    ;;
esac
