#!/usr/bin/env bash
set -euo pipefail

DOT_PI_DIR="$(cd "$(dirname "$0")" && pwd)"
SHARED_DIR="$DOT_PI_DIR/shared"

usage() {
  cat <<EOF
dot-pi manager

Usage: $(basename "$0") <command> [args]

Commands:
  init                                     Interactive setup wizard (API keys, models, roles)
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

# ── init: interactive setup wizard ────────────────────────────────────────────

_init_check_deps() {
  local missing=()
  command -v jq &>/dev/null || missing+=(jq)
  command -v curl &>/dev/null || missing+=(curl)
  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: missing required tools: ${missing[*]}"
    echo "  brew install ${missing[*]}  (macOS)"
    echo "  apt install ${missing[*]}   (Debian/Ubuntu)"
    exit 1
  fi
}

_init_mask() {
  local val="$1"
  if [ -z "$val" ]; then
    echo "(empty)"
  elif [ ${#val} -le 8 ]; then
    echo "****"
  else
    echo "${val:0:4}****${val: -2}"
  fi
}

_init_read_env_var() {
  local file="$1" varname="$2"
  if [ -f "$file" ]; then
    grep "^export ${varname}=" "$file" 2>/dev/null | head -1 | sed "s/^export ${varname}=//"
  fi
}

_init_prompt_key() {
  local varname="$1" current="$2" label="$3"
  local masked
  masked=$(_init_mask "$current")
  local input
  read -r -p "  ${label:-$varname} [$masked]: " input
  if [ -z "$input" ]; then
    echo "$current"
  elif [ "$input" = "-" ]; then
    echo ""
  else
    echo "$input"
  fi
}

_init_select_model() {
  local role="$1" current="$2"
  shift 2
  local models=("$@")

  local hint=""
  [ -n "$current" ] && hint=" (current: $current)"
  echo "  $role$hint"

  local i
  for i in "${!models[@]}"; do
    local marker="  "
    [ "${models[$i]}" = "$current" ] && marker="> "
    printf "    %s%d) %s\n" "$marker" "$((i + 1))" "${models[$i]}"
  done
  printf "    %s%d) %s\n" "  " "$((${#models[@]} + 1))" "(skip)"

  local choice
  read -r -p "    choice [Enter=keep]: " choice
  if [ -z "$choice" ]; then
    echo "$current"
  elif [ "$choice" = "-" ]; then
    echo ""
  elif [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "${#models[@]}" ]; then
    echo "${models[$((choice - 1))]}"
  elif [ "$choice" -eq "$((${#models[@]} + 1))" ] 2>/dev/null; then
    echo ""
  else
    echo >&2 "    invalid choice, keeping current"
    echo "$current"
  fi
}

init_setup() {
  _init_check_deps

  echo ""
  echo "dot-pi setup"
  echo "============"
  echo ""
  echo "Re-run anytime. Press Enter to keep current values, type to replace, - to clear."
  echo ""

  # ── Step 1: Provider endpoint ──────────────────────────────────────────────
  echo "[1/5] Provider endpoint"
  echo ""

  local cur_base_url="" cur_api_type="" cur_api_key_var=""
  if [ -f "$SHARED_DIR/models.json" ]; then
    cur_base_url=$(jq -r '.providers | to_entries[0].value.baseUrl // ""' "$SHARED_DIR/models.json" 2>/dev/null)
    cur_api_type=$(jq -r '.providers | to_entries[0].value.api // ""' "$SHARED_DIR/models.json" 2>/dev/null)
    cur_api_key_var=$(jq -r '.providers | to_entries[0].value.apiKey // ""' "$SHARED_DIR/models.json" 2>/dev/null)
  fi
  # Strip trailing slash from stored URL
  cur_base_url="${cur_base_url%/}"
  cur_api_type="${cur_api_type:-openai}"
  cur_api_key_var="${cur_api_key_var:-PLEBCHAT_API_KEY}"

  local base_url="$cur_base_url" api_type="$cur_api_type"

  if [ -n "$cur_base_url" ]; then
    echo "  Current: $cur_base_url ($cur_api_type)"
    local edit_endpoint
    read -r -p "  Change endpoint? [y/N]: " edit_endpoint
    if [[ "$edit_endpoint" =~ ^[Yy] ]]; then
      read -r -p "  Base URL [$cur_base_url]: " base_url
      base_url="${base_url:-$cur_base_url}"
      base_url="${base_url%/}"

      echo "  API compatibility:"
      echo "    1) openai"
      echo "    2) anthropic-messages"
      local api_choice default_n=1
      [ "$cur_api_type" = "anthropic-messages" ] && default_n=2
      read -r -p "  choice [$default_n]: " api_choice
      api_choice="${api_choice:-$default_n}"
      [ "$api_choice" = "2" ] && api_type="anthropic-messages" || api_type="openai"
    fi
  else
    read -r -p "  Base URL [https://localhost:1234]: " base_url
    base_url="${base_url:-https://localhost:1234}"
    base_url="${base_url%/}"

    echo "  API compatibility:"
    echo "    1) openai"
    echo "    2) anthropic-messages"
    local api_choice
    read -r -p "  choice [1]: " api_choice
    api_choice="${api_choice:-1}"
    [ "$api_choice" = "2" ] && api_type="anthropic-messages" || api_type="openai"
  fi

  echo ""

  # ── Step 2: API keys ──────────────────────────────────────────────────────
  echo "[2/5] API keys (.env)"
  echo ""

  local env_file="$DOT_PI_DIR/.env"
  local example_file="$DOT_PI_DIR/.env.example"

  # Collect key names from .env.example
  local key_names=()
  if [ -f "$example_file" ]; then
    while IFS= read -r line || [ -n "$line" ]; do
      [[ "$line" =~ ^export\ ([A-Za-z_][A-Za-z0-9_]*)= ]] && key_names+=("${BASH_REMATCH[1]}")
    done < "$example_file"
  fi
  [ ${#key_names[@]} -eq 0 ] && key_names=(PLEBCHAT_API_KEY TAVILY_API_KEY XAI_API_KEY)

  # Use parallel indexed array for values (bash 3.x compat -- no declare -A)
  local env_vals=()
  local ki kn
  for ki in "${!key_names[@]}"; do
    kn="${key_names[$ki]}"
    local cur
    cur=$(_init_read_env_var "$env_file" "$kn")
    env_vals+=("$(_init_prompt_key "$kn" "$cur" "$kn")")
  done

  # Find provider API key value by matching key_names to cur_api_key_var
  local provider_api_key_var="$cur_api_key_var"
  local provider_api_key=""
  for ki in "${!key_names[@]}"; do
    if [ "${key_names[$ki]}" = "$provider_api_key_var" ]; then
      provider_api_key="${env_vals[$ki]}"
      break
    fi
  done

  # Write .env
  {
    for ki in "${!key_names[@]}"; do
      echo "export ${key_names[$ki]}=${env_vals[$ki]}"
    done
  } > "$env_file"
  echo ""
  echo "  Wrote $env_file"
  echo ""

  # ── Step 3: Fetch models ───────────────────────────────────────────────────
  echo "[3/5] Fetch models from $base_url"
  echo ""

  local curl_args=(-s --connect-timeout 10 --max-time 20)
  if [ -n "$provider_api_key" ]; then
    curl_args+=(-H "Authorization: Bearer $provider_api_key")
  fi

  local raw_response model_ids=() model_names=()
  raw_response=$(curl "${curl_args[@]}" "$base_url/v1/models" 2>/dev/null) || true

  if [ -n "$raw_response" ] && echo "$raw_response" | jq -e '.data' &>/dev/null; then
    local count
    count=$(echo "$raw_response" | jq '.data | length')
    echo "  Found $count model(s):"
    echo ""

    local idx=0
    while IFS=$'\t' read -r mid mname; do
      model_ids+=("$mid")
      model_names+=("${mname:-$mid}")
      idx=$((idx + 1))
      printf "    %d) %s  (%s)\n" "$idx" "$mid" "${mname:-$mid}"
    done < <(echo "$raw_response" | jq -r '.data[] | [.id, (.name // .id)] | @tsv')

    echo ""
    echo "  Enter model numbers to include (comma-separated), or Enter for all:"
    local selection
    read -r -p "  models [all]: " selection

    if [ -n "$selection" ]; then
      local selected_ids=() selected_names=()
      IFS=',' read -ra sel_nums <<< "$selection"
      local n
      for n in "${sel_nums[@]}"; do
        n=$(echo "$n" | tr -d ' ')
        if [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le "${#model_ids[@]}" ]; then
          selected_ids+=("${model_ids[$((n - 1))]}")
          selected_names+=("${model_names[$((n - 1))]}")
        fi
      done
      model_ids=("${selected_ids[@]}")
      model_names=("${selected_names[@]}")
    fi
  else
    echo "  Could not fetch models from $base_url/v1/models"
    if [ -n "$raw_response" ]; then
      echo "  Response: $(echo "$raw_response" | head -c 200)"
    fi
    echo ""
    echo "  Enter model IDs manually (comma-separated):"

    local existing_ids=""
    if [ -f "$SHARED_DIR/models.json" ]; then
      existing_ids=$(jq -r '.providers | to_entries[0].value.models[]?.id' "$SHARED_DIR/models.json" 2>/dev/null | paste -sd, -)
    fi

    local manual
    read -r -p "  models [${existing_ids:-}]: " manual
    manual="${manual:-$existing_ids}"
    if [ -n "$manual" ]; then
      IFS=',' read -ra parts <<< "$manual"
      local p
      for p in "${parts[@]}"; do
        p=$(echo "$p" | xargs)
        [ -n "$p" ] && model_ids+=("$p") && model_names+=("$p")
      done
    fi
  fi

  if [ ${#model_ids[@]} -eq 0 ]; then
    echo "  No models configured. You can edit shared/models.json manually later."
    echo ""
  fi

  # Derive a provider name from the base URL hostname
  local provider_name
  provider_name=$(echo "$base_url" | sed -E 's|https?://||; s|[/:].*||; s/\..*//; s/[^a-zA-Z0-9_-]/_/g')
  [ -z "$provider_name" ] && provider_name="provider"

  # Build models JSON array entries, preserving metadata from existing models.json
  local models_json_array="["
  local i
  for i in "${!model_ids[@]}"; do
    [ "$i" -gt 0 ] && models_json_array+=","
    local mid="${model_ids[$i]}"
    local mname="${model_names[$i]}"

    local reasoning="false" input='["text"]' ctx=131072
    if [ -f "$SHARED_DIR/models.json" ]; then
      local existing
      existing=$(jq -r --arg id "$mid" \
        '.providers | to_entries[0].value.models[] | select(.id == $id)' \
        "$SHARED_DIR/models.json" 2>/dev/null)
      if [ -n "$existing" ]; then
        reasoning=$(echo "$existing" | jq -r '.reasoning // false')
        input=$(echo "$existing" | jq -c '.input // ["text"]')
        ctx=$(echo "$existing" | jq -r '.contextWindow // 131072')
        mname=$(echo "$existing" | jq -r '.name // ""')
        [ -z "$mname" ] && mname="${model_names[$i]}"
      fi
    fi

    models_json_array+=$(jq -n \
      --arg id "$mid" \
      --arg name "$mname" \
      --argjson reasoning "$reasoning" \
      --argjson input "$input" \
      --argjson ctx "$ctx" \
      '{id: $id, name: $name, reasoning: $reasoning, input: $input, contextWindow: $ctx}')
  done
  models_json_array+="]"

  # Write models.json
  mkdir -p "$SHARED_DIR"
  jq -n \
    --arg pname "$provider_name" \
    --arg baseUrl "$base_url/" \
    --arg api "$api_type" \
    --arg apiKey "$provider_api_key_var" \
    --argjson models "$models_json_array" \
    '{providers: {($pname): {baseUrl: $baseUrl, api: $api, apiKey: $apiKey, models: $models}}}' \
    > "$SHARED_DIR/models.json"

  echo ""
  echo "  Wrote $SHARED_DIR/models.json (${#model_ids[@]} models)"
  echo ""

  # ── Step 4: Model roles ───────────────────────────────────────────────────
  echo "[4/5] Model roles (model_roles)"
  echo ""

  local roles_file="$DOT_PI_DIR/model_roles"
  local role_names=(AGENTIC_MODEL THINKING_MODEL CODING_MODEL VISION_MODEL FAST_MODEL)

  # Prefix model IDs with provider name for pi's provider/model syntax
  local prefixed_ids=()
  for mid in "${model_ids[@]}"; do
    prefixed_ids+=("${provider_name}/${mid}")
  done

  # Use parallel indexed array for role values (bash 3.x compat)
  local role_vals=()
  local role
  for role in "${role_names[@]}"; do
    local cur
    cur=$(_init_read_env_var "$roles_file" "$role")
    role_vals+=("$(_init_select_model "$role" "$cur" "${prefixed_ids[@]}")")
    echo ""
  done

  # Write model_roles
  {
    local ri
    for ri in "${!role_names[@]}"; do
      echo "export ${role_names[$ri]}=${role_vals[$ri]}"
    done
  } > "$roles_file"
  echo "  Wrote $roles_file"
  echo ""

  # ── Step 5: Verify ────────────────────────────────────────────────────────
  echo "[5/5] Summary"
  echo ""

  echo "  Provider:  $base_url ($api_type)"
  echo "  Models:    ${#model_ids[@]} configured"
  for ki in "${!key_names[@]}"; do
    echo "  ${key_names[$ki]}: $(_init_mask "${env_vals[$ki]}")"
  done
  local ri
  for ri in "${!role_names[@]}"; do
    local v="${role_vals[$ri]}"
    echo "  ${role_names[$ri]}: ${v:-(not set)}"
  done

  local warnings=0
  [ -z "${env_vals[0]:-}" ] && echo "" && echo "  Warning: ${key_names[0]} is empty" && warnings=1
  [ ${#model_ids[@]} -eq 0 ] && echo "  Warning: no models configured" && warnings=1

  echo ""
  if [ "$warnings" -eq 0 ]; then
    echo "  Setup complete!"
  else
    echo "  Setup complete (with warnings -- re-run to fix)."
  fi
  echo ""
  echo "  Next steps:"
  echo "    1. Add to your shell profile:  source $DOT_PI_DIR/bash_aliases"
  echo "    2. Start a session:            p talk"
  echo ""
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

  # Symlink shared Pi settings (theme, defaults, etc.)
  ln -sf "../../shared/settings.json" "$team_dir/settings.json"

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
  echo "    settings.json        (symlink → shared/settings.json)"
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

  # Symlink shared Pi settings (theme, defaults, etc.)
  ln -sf "../../shared/settings.json" "$agent_dir/settings.json"

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
  echo "    settings.json            (symlink → shared/settings.json)"
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
  init)
    init_setup
    ;;
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
