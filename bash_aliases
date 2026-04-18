# ── dot-pi: unified pi agent launcher ───────────────────────────────────────
#
# Source this file from ~/.bashrc or ~/.zshrc:
#   source ~/path/to/dot-pi/bash_aliases
#
# Provides a single `p` command that dispatches to any team or agent:
#   p <name> [flags...] [prompt]
#   echo "prompt" | p <name>
#
# DOT_PI_DIR is auto-detected from this script's location.
# Override by setting DOT_PI_DIR before sourcing.

# disable version telemetry (shell-local; export in your profile if you want it on bare `pi`)
PI_TELEMETRY=0

# auto-detect DOT_PI_DIR from this script's location
if [ -n "${ZSH_VERSION:-}" ]; then
    DOT_PI_DIR="${DOT_PI_DIR:-$(cd "$(dirname "${(%):-%x}")" && pwd)}"
else
    DOT_PI_DIR="${DOT_PI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}"
fi

# Load API keys if present
[ -f "$DOT_PI_DIR/.env" ] && source "$DOT_PI_DIR/.env"

# pi when launched through `p` / workspace helpers only — skips npm + extension update toasts.
# Plain `pi` in your shell is unchanged unless you export these yourself.
_dotmi_pi() {
	PI_SKIP_VERSION_CHECK=1 PI_OFFLINE=1 command pi "$@"
}

# ── session explorer (Pi JSONL + pi-web-ui) ─────────────────────────────────
# Dev: Vite + API on 127.0.0.1. Prod: npm run build && npm run start (see tools/session-explorer/README.md).
p_sessions() {
	( cd "$DOT_PI_DIR/tools/session-explorer" && npm run dev )
}

# ── workspace launcher ───────────────────────────────────────────────────────
#
# Used by `p` when a team/agent has a workspace.conf file.
# Creates a fresh dated directory, pre-creates subdirs listed in workspace.conf,
# then launches pi inside a subshell so the user's shell stays put after exit.
#
# Flags:
#   --list              Show existing workspaces and exit
#   --resume [prefix]   Resume into an existing workspace (most recent, or by prefix)

_dotmi_workspace_launch() {
  local name="$1" config_dir="$2"
  shift 2
  local ws_root="$DOT_PI_DIR/workspaces/$name"

  # --list: show existing workspaces and exit
  if [ "${1:-}" = "--list" ]; then
    if [ ! -d "$ws_root" ] || [ -z "$(ls -A "$ws_root" 2>/dev/null)" ]; then
      echo "No workspaces for $name"
      return 0
    fi
    echo "Workspaces for $name:"
    for d in "$ws_root"/*/; do
      [ -d "$d" ] || continue
      local ts=$(basename "$d")
      local files=$(find "$d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
      echo "  $ts  ($files files)"
    done
    return 0
  fi

  # --resume [prefix]: cd into existing workspace instead of creating new
  if [ "${1:-}" = "--resume" ]; then
    shift
    local target
    if [ -n "${1:-}" ]; then
      target=$(ls -d "$ws_root"/"$1"* 2>/dev/null | tail -1)
      if [ -z "$target" ]; then
        echo "No workspace matching '$1' in $ws_root"
        return 1
      fi
      shift
    else
      target=$(ls -dt "$ws_root"/*/ 2>/dev/null | head -1)
      if [ -z "$target" ]; then
        echo "No workspaces to resume for $name"
        return 1
      fi
    fi
    echo "Resuming: $target" >&2
    local _resume_args=()
    [ -d "$target/sessions" ] && _resume_args+=(--session-dir "$target/sessions")
    (cd "$target" && PI_CODING_AGENT_DIR="$config_dir" _dotmi_pi "${_resume_args[@]}" --resume "$@")
    return $?
  fi

  # Default: create fresh workspace
  local ws="$ws_root/$(date +%Y-%m-%d-%H%M%S)"
  mkdir -p "$ws"
  # `|| [ -n "$subdir" ]` ensures the last line is processed if the file has no final newline.
  while IFS= read -r subdir || [ -n "$subdir" ]; do
    [[ -n "$subdir" && "$subdir" != \#* ]] && mkdir -p "$ws/$subdir"
  done < "$config_dir/workspace.conf"
  echo "Workspace: $ws" >&2
  local _launch_args=()
  [ -d "$ws/sessions" ] && _launch_args+=(--session-dir "$ws/sessions")
  (cd "$ws" && PI_CODING_AGENT_DIR="$config_dir" _dotmi_pi "${_launch_args[@]}" "$@")
  return $?
}

# ── retro workspace runner ──────────────────────────────────────────────────
#
# Non-interactive retro analysis targeting workspace directories.
# For manual in-situ use: p retro
#
# User-facing:
#   run-retro <team>                        Analyze latest workspace
#   run-retro <team> <date-prefix>          Analyze workspace matching prefix
#   run-retro <team> --list                 List workspaces for team
#   run-retro <team> --pick                 Interactive menu to choose a workspace
#   run-retro <team> [date] -- "hint"       With optional steering prompt
#
# Internal (used by eval script):
#   run-retro --workspace-path <path> [-- "hint"]

run-retro() {
  local ws_path="" hint="" team=""

  if [ "${1:-}" = "--workspace-path" ]; then
    [ -z "${2:-}" ] && { echo "Error: --workspace-path requires a path" >&2; return 1; }
    ws_path="$2"
    shift 2
    team=$(basename "$(dirname "$ws_path")")
    if [ "${1:-}" = "--" ]; then shift; hint="$*"; fi
  else
    team="${1:?Usage: run-retro <team> [--list|--pick] [date-prefix] [-- hint]}"
    shift
    local ws_root="$DOT_PI_DIR/workspaces/$team"

    if [ "${1:-}" = "--list" ]; then
      if [ ! -d "$ws_root" ] || [ -z "$(ls -A "$ws_root" 2>/dev/null)" ]; then
        echo "No workspaces for $team"
        return 0
      fi
      echo "Workspaces for $team:"
      for d in "$ws_root"/*/; do
        [ -d "$d" ] || continue
        local ts=$(basename "$d")
        local files=$(find "$d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
        local has_retro=""
        [ -f "$d/retrospective-report.md" ] && has_retro="  [retro]"
        echo "  $ts  ($files files)$has_retro"
      done
      return 0
    fi

    if [ "${1:-}" = "--pick" ]; then
      shift
      local pick_paths=()
      local pick_labels=()
      local _d
      while IFS= read -r _d; do
        [ -z "$_d" ] && continue
        _d="${_d%/}"
        [ ! -d "$_d" ] && continue
        pick_paths+=("$_d")
        local _ts=$(basename "$_d")
        local _files=$(find "$_d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
        local _hr=""
        [ -f "$_d/retrospective-report.md" ] && _hr=" [retro]"
        pick_labels+=("$_ts  ($_files files)$_hr")
      done < <(ls -dt "$ws_root"/*/ 2>/dev/null)
      if [ ${#pick_paths[@]} -eq 0 ]; then
        echo "No workspaces for $team" >&2
        return 1
      fi
      echo "Select a workspace for $team:"
      local PS3="Number: "
      local _choice
      select _choice in "${pick_labels[@]}" "Cancel"; do
        if [ "$_choice" = "Cancel" ]; then
          echo "Cancelled." >&2
          return 1
        fi
        if [ -z "$_choice" ]; then
          echo "Invalid choice; try again." >&2
          continue
        fi
        local _idx=$((REPLY - 1))
        if [ "$_idx" -ge 0 ] && [ "$_idx" -lt ${#pick_paths[@]} ]; then
          ws_path="${pick_paths[$_idx]}"
          break
        fi
        echo "Invalid choice; try again." >&2
      done
    elif [ -n "${1:-}" ] && [ "$1" != "--" ]; then
      ws_path=$(ls -d "$ws_root/$1"* 2>/dev/null | tail -1)
      [ -z "$ws_path" ] && { echo "No workspace matching '$1' in $ws_root" >&2; return 1; }
      shift
    else
      ws_path=$(ls -dt "$ws_root"/*/ 2>/dev/null | head -1)
      [ -z "$ws_path" ] && { echo "No workspaces for $team" >&2; return 1; }
    fi

    if [ "${1:-}" = "--" ]; then shift; hint="$*"; fi
  fi

  [ ! -d "$ws_path" ] && { echo "Error: workspace not found: $ws_path" >&2; return 1; }

  local team_prompt="$DOT_PI_DIR/teams/$team/team-prompt.md"
  if [ -f "$team_prompt" ] && [ ! -e "$ws_path/.source-team-prompt.md" ]; then
    ln -s "$team_prompt" "$ws_path/.source-team-prompt.md"
  fi

  local prompt="Analyze this $team workspace."
  [ -n "$hint" ] && prompt="$prompt Focus: $hint"

  local retro_dir="$DOT_PI_DIR/teams/retro"
  local retro_sessions="$retro_dir/sessions"
  mkdir -p "$retro_sessions"
  echo "Retro: $ws_path" >&2
  (cd "$ws_path" && PI_CODING_AGENT_DIR="$retro_dir" pi --mode json \
    --session-dir "$retro_sessions" -p "$prompt" < /dev/null) | _dotmi_json_filter
  return ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
}

# ── p: unified agent dispatcher ──────────────────────────────────────────────
#
# Single entry point for all teams and standalone agents under DOT_PI_DIR.
#
#   p                                   List available names (stderr)
#   p <name> [flags...] [prompt]        Team or agent by name
#   p <name> -p "do something"          Explicit prompt (non-interactive)
#   echo "do something" | p <name>      Pipe stdin as prompt (non-interactive)
#   p <name>                            Interactive (tty)
#   p <name> --list                     Workspace teams: list past runs
#   p <name> --resume [prefix]          Workspace teams: resume a run

_dotmi_has_flag() {
  local flag="$1"; shift
  for arg in "$@"; do [ "$arg" = "$flag" ] && return 0; done
  return 1
}

# Lists teams and standalone agents (name, kind, mode) on stderr, sorted by name.
# kind: team | agent — mode: workspace (has workspace.conf) | in-situ
# Uses find (not glob + shopt) so this works when bash_aliases is sourced from zsh.
_dotmi_list_available() {
  echo "Available:" >&2
  printf '  %-20s  %-8s  %s\n' "name" "kind" "mode" >&2
  {
    find "$DOT_PI_DIR/teams" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | while IFS= read -r d; do
      [ -n "$d" ] || continue
      name=$(basename "$d")
      mode=$([ -f "$d/workspace.conf" ] && echo workspace || echo in-situ)
      printf '%s\tteam\t%s\n' "$name" "$mode"
    done
    find "$DOT_PI_DIR/agents" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort | while IFS= read -r d; do
      [ -n "$d" ] || continue
      name=$(basename "$d")
      mode=$([ -f "$d/workspace.conf" ] && echo workspace || echo in-situ)
      printf '%s\tagent\t%s\n' "$name" "$mode"
    done
  } | sort -t $'\t' -k1,1 | while IFS=$'\t' read -r name kind mode; do
    printf '  %-20s  %-8s  %s\n' "$name" "$kind" "$mode" >&2
  done
}

# ── batch mode filter ────────────────────────────────────────────────────────
#
# Reads pi's --mode json event stream from stdin.
# Emits compact progress lines to stderr.
# Emits only the final assistant text to stdout.

_dotmi_json_filter() {
  local turn=0 final_text=""
  while IFS= read -r line; do
    local type
    type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null) || continue
    case "$type" in
      turn_start)
        turn=$((turn + 1))
        ;;
      tool_execution_start)
        local tool_name
        tool_name=$(printf '%s' "$line" | jq -r '.toolName // "?"')
        printf '[turn %d] tool: %s\n' "$turn" "$tool_name" >&2
        ;;
      tool_execution_end)
        local tool_name is_err
        tool_name=$(printf '%s' "$line" | jq -r '.toolName // "?"')
        is_err=$(printf '%s' "$line" | jq -r '.isError // false')
        if [ "$is_err" = "true" ]; then
          printf '[turn %d] tool: %s ERROR\n' "$turn" "$tool_name" >&2
        fi
        ;;
      message_end)
        local role text
        role=$(printf '%s' "$line" | jq -r '.message.role // empty')
        if [ "$role" = "assistant" ]; then
          text=$(printf '%s' "$line" | jq -r '
            [.message.content[]? | select(.type == "text") | .text]
            | join("\n")' 2>/dev/null)
          [ -n "$text" ] && final_text="$text"
        fi
        ;;
      agent_end)
        printf '[agent done]\n' >&2
        ;;
    esac
  done
  [ -n "$final_text" ] && printf '%s\n' "$final_text"
}

p() {
  if [ "$#" -eq 0 ] || [ -z "${1:-}" ]; then
    echo "Usage: p <name> [flags...] [prompt]" >&2
    _dotmi_list_available
    return 0
  fi
  local name="$1"
  shift

  # Resolve config directory: teams/ first, then agents/
  local config_dir=""
  if [ -d "$DOT_PI_DIR/teams/$name" ]; then
    config_dir="$DOT_PI_DIR/teams/$name"
  elif [ -d "$DOT_PI_DIR/agents/$name" ]; then
    config_dir="$DOT_PI_DIR/agents/$name"
  else
    echo "p: unknown agent or team: $name" >&2
    _dotmi_list_available
    return 1
  fi

  # Detect batch mode: non-tty stdin or -p flag present
  local _batch=false
  if [ ! -t 0 ] || _dotmi_has_flag "-p" "$@"; then
    _batch=true
  fi

  # Stdin pipe detection: if stdin is not a tty and -p wasn't given,
  # read stdin and pass it as -p.
  if [ ! -t 0 ] && ! _dotmi_has_flag "-p" "$@"; then
    local _stdin_prompt
    _stdin_prompt=$(cat)
    set -- -p "$_stdin_prompt" "$@"
  fi

  # In batch mode, use JSON event stream and pipe through progress filter.
  # Progress goes to stderr, final assistant text goes to stdout.
  if [ "$_batch" = true ]; then
    set -- --mode json "$@"
  fi

  # Load default CLI flags from pi-args if present.
  # One flag (or flag + value) per line. Lines starting with # are comments.
  if [ -f "$config_dir/pi-args" ]; then
    local _pi_args=()
    # `|| [ -n "$_line" ]` ensures the last line is processed if the file has no final newline.
    while IFS= read -r _line || [ -n "$_line" ]; do
      [[ -n "$_line" && "$_line" != \#* ]] && _pi_args+=($_line)
    done < "$config_dir/pi-args"
    if [ ${#_pi_args[@]} -gt 0 ]; then
      set -- "${_pi_args[@]}" "$@"
    fi
  fi

  # Dispatch: workspace or in-situ
  if [ -f "$config_dir/workspace.conf" ]; then
    if [ "$_batch" = true ]; then
      _dotmi_workspace_launch "$name" "$config_dir" "$@" | _dotmi_json_filter
      return ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
    else
      _dotmi_workspace_launch "$name" "$config_dir" "$@"
      return $?
    fi
  else
    if [ "$_batch" = true ]; then
      PI_CODING_AGENT_DIR="$config_dir" _dotmi_pi "$@" | _dotmi_json_filter
      return ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
    else
      PI_CODING_AGENT_DIR="$config_dir" _dotmi_pi "$@"
      return $?
    fi
  fi
}

# ── Zsh: tab completion for `p` ───────────────────────────────────────────────
# zsh-only globs cannot live in this file: bash parses the whole script when sourced
# from ~/.bashrc, so the implementation is in p-completion.zsh.
# Initialize zsh completion system
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz compinit && compinit
fi
if [ -n "${ZSH_VERSION:-}" ] && [ -f "$DOT_PI_DIR/p-completion.zsh" ]; then
  . "$DOT_PI_DIR/p-completion.zsh"
fi
