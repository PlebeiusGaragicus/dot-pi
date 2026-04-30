# Workspace agent launch/list/resume helpers.

_workspace_label() {
  local agent="$1" path="$2" base files ts title
  base=$(basename "$path")
  ts="${base%%--*}"
  if [[ "$base" == *"--"* ]]; then
    title="${base#*--}"
    title="${title//-/ }"
  else
    title=""
  fi
  files=$(find "$path" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
  if [ -n "$title" ]; then
    printf '%-18s  %-15s  %-36s  (%s files)' "$agent" "$ts" "$title" "$files"
  else
    printf '%-18s  %-15s  %-36s  (%s files)' "$agent" "$ts" "-" "$files"
  fi
}

_resume_workspace_path() {
  local ws_path="$1"
  ws_path="${ws_path%/}"
  local agent config_dir
  agent=$(basename "$(dirname "$ws_path")")
  config_dir="$DOT_PI_DIR/agents/$agent"
  [ -d "$config_dir" ] || { echo "No agent config for workspace: $agent" >&2; return 1; }
  _load_pi_args "$config_dir"
  _filter_model_flags "$config_dir"
  echo "Resuming: $ws_path" >&2
  local cmd_args=()
  [ ${#_pi_args[@]} -gt 0 ] && cmd_args+=("${_pi_args[@]}")
  (
    cd "$ws_path"
    _source_bootstrap "$config_dir" "resume" "$ws_path" "$agent"
    local _resume_args=()
    [ -d "$ws_path/sessions" ] && _resume_args+=(--session-dir "$ws_path/sessions")
    [ "$_cli_print" = true ] && cmd_args+=(--mode json)
    [ ${#_resume_args[@]} -gt 0 ] && cmd_args+=("${_resume_args[@]}")
    cmd_args+=(--continue)
    _build_prompt_args
    [ ${#_prompt_args[@]} -gt 0 ] && cmd_args+=("${_prompt_args[@]}")
    if [ "$_cli_print" = true ]; then
      _run_pi_with_args_array "$config_dir" cmd_args < /dev/null
    else
      _run_pi_with_args_array "$config_dir" cmd_args
    fi
  )
}

_pick_workspace() {
  local title="$1"
  shift
  local paths=("$@")
  if [ ${#paths[@]} -eq 0 ]; then
    echo "No workspaces found" >&2
    return 1
  fi
  echo "$title" >&2
  local i=1 path agent
  for path in "${paths[@]}"; do
    agent=$(basename "$(dirname "${path%/}")")
    printf '%2d) %s\n' "$i" "$(_workspace_label "$agent" "$path")" >&2
    i=$((i + 1))
  done
  local reply
  while true; do
    printf 'Number: ' >&2
    IFS= read -r reply || return 1
    case "$reply" in
      ''|*[!0-9]*)
        echo "Invalid choice; enter a number." >&2
        ;;
      *)
        if [ "$reply" -ge 1 ] && [ "$reply" -le ${#paths[@]} ]; then
          printf '%s\n' "${paths[$((reply - 1))]}"
          return 0
        fi
        echo "Invalid choice; enter 1-${#paths[@]}." >&2
        ;;
    esac
  done
}

_collect_workspaces() {
  local limit="${1:-10}" query="${2:-}" d agent base haystack count=0
  shopt -s nullglob
  for d in "$DOT_PI_DIR"/workspaces/*/*/; do
    [ -d "$d" ] || continue
    agent=$(basename "$(dirname "${d%/}")")
    _is_workspace_agent "$DOT_PI_DIR/agents/$agent" || continue
    base=$(basename "${d%/}")
    haystack=$(printf '%s %s %s' "$agent" "$base" "${base//-/ }" | tr '[:upper:]' '[:lower:]')
    if [ -n "$query" ] && [[ "$haystack" != *"$(printf '%s' "$query" | tr '[:upper:]' '[:lower:]')"* ]]; then
      continue
    fi
    printf '%s\t%s\n' "$(stat -f '%m' "$d" 2>/dev/null || stat -c '%Y' "$d" 2>/dev/null || echo 0)" "${d%/}"
  done | sort -rn | while IFS=$'\t' read -r _mtime d; do
    [ -n "$d" ] || continue
    printf '%s\n' "$d"
    count=$((count + 1))
    [ "$count" -ge "$limit" ] && break
  done
}

_workspace_launch() {
  local name="$1" config_dir="$2"
  local ws_root="$DOT_PI_DIR/workspaces/$name"
  local slug ws

  ws="$ws_root/$(date +%Y-%m-%d-%H%M%S)"
  if [ -n "$_cli_workspace_name" ]; then
    slug="$(_slugify_workspace_name "$_cli_workspace_name")"
    ws="$ws--$slug"
  fi
  mkdir -p "$ws"
  echo "Workspace: $ws" >&2
  _filter_model_flags "$config_dir"
  local cmd_args=()
  [ ${#_pi_args[@]} -gt 0 ] && cmd_args+=("${_pi_args[@]}")
  (
    cd "$ws"
    _source_bootstrap "$config_dir" "fresh" "$ws" "$name"
    local _launch_args=()
    [ -d "$ws/sessions" ] && _launch_args+=(--session-dir "$ws/sessions")
    [ "$_cli_print" = true ] && cmd_args+=(--mode json)
    [ ${#_launch_args[@]} -gt 0 ] && cmd_args+=("${_launch_args[@]}")
    _build_prompt_args
    [ ${#_prompt_args[@]} -gt 0 ] && cmd_args+=("${_prompt_args[@]}")
    if [ "$_cli_print" = true ]; then
      _run_pi_with_args_array "$config_dir" cmd_args < /dev/null
    else
      _run_pi_with_args_array "$config_dir" cmd_args
    fi
  )
  return $?
}

_workspace_list() {
  local name="$1"
  local ws_root="$DOT_PI_DIR/workspaces/$name"
  if [ ! -d "$ws_root" ] || [ -z "$(ls -A "$ws_root" 2>/dev/null)" ]; then
    echo "No workspaces for $name"
    return 0
  fi
  echo "Workspaces for $name:"
  for d in "$ws_root"/*/; do
    [ -d "$d" ] || continue
    local ts files
    ts=$(basename "$d")
    files=$(find "$d" -maxdepth 2 -type f 2>/dev/null | wc -l | tr -d ' ')
    echo "  $ts  ($files files)"
  done
}

_workspace_resume() {
  local name="$1" prefix="${2:-}" target slug d base
  local ws_root="$DOT_PI_DIR/workspaces/$name"
  if [ -n "$prefix" ]; then
    slug="$(_slugify_workspace_name "$prefix")"
    while IFS= read -r d; do
      [ -n "$d" ] || continue
      base=$(basename "${d%/}")
      if [[ "$base" == "$prefix"* || "$base" == *"--$slug"* ]]; then
        target="${d%/}"
        break
      fi
    done < <(ls -dt "$ws_root"/*/ 2>/dev/null)
    if [ -z "$target" ]; then
      echo "No workspace matching '$prefix' in $ws_root"
      return 1
    fi
  else
    target=$(ls -dt "$ws_root"/*/ 2>/dev/null | head -1)
    if [ -z "$target" ]; then
      echo "No workspaces to resume for $name"
      return 1
    fi
  fi
  _resume_workspace_path "$target"
}

_resume_global() {
  local query="$*"
  local paths=() selected
  while IFS= read -r selected; do
    [ -n "$selected" ] && paths+=("$selected")
  done < <(_collect_workspaces 10 "$query")
  if [ ${#paths[@]} -eq 0 ]; then
    if [ -n "$query" ]; then
      echo "No workspaces matching '$query'" >&2
    else
      echo "No workspaces found" >&2
    fi
    return 1
  fi
  selected=$(_pick_workspace "Recent workspaces:" "${paths[@]}") || return $?
  _resume_workspace_path "$selected"
}

