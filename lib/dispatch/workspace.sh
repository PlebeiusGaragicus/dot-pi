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
  echo "Resuming: $ws_path" >&2
  (
    cd "$ws_path"
    _source_bootstrap "$config_dir" "resume" "$ws_path" "$agent"
    local session_dir=""
    [ -d "$ws_path/sessions" ] && session_dir="$ws_path/sessions"
    _build_pi_command_args "$config_dir" "$session_dir" true
    _run_pi_command "$config_dir"
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

_collect_agent_workspaces() {
  local name="$1" limit="${2:-0}" ws_root="$DOT_PI_DIR/workspaces/$name"
  local d count=0
  shopt -s nullglob
  for d in "$ws_root"/*/; do
    [ -d "$d" ] || continue
    printf '%s\t%s\n' "$(stat -f '%m' "$d" 2>/dev/null || stat -c '%Y' "$d" 2>/dev/null || echo 0)" "${d%/}"
  done | sort -rn | while IFS=$'\t' read -r _mtime d; do
    [ -n "$d" ] || continue
    printf '%s\n' "$d"
    count=$((count + 1))
    [ "$limit" -gt 0 ] && [ "$count" -ge "$limit" ] && break
  done
}

_resolve_workspace_exact() {
  local name="$1" target="$2" ws_root="$DOT_PI_DIR/workspaces/$name" candidate
  target="${target%/}"
  if [ -d "$target" ]; then
    candidate="$target"
  else
    candidate="$ws_root/$target"
  fi
  if [ ! -d "$candidate" ]; then
    echo "No workspace named '$target' under $ws_root" >&2
    return 1
  fi
  candidate="${candidate%/}"
  if [ "$(basename "$(dirname "$candidate")")" != "$name" ]; then
    echo "Workspace is not for $name: $candidate" >&2
    return 1
  fi
  printf '%s\n' "$candidate"
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
  (
    cd "$ws"
    _source_bootstrap "$config_dir" "fresh" "$ws" "$name"
    local session_dir=""
    [ -d "$ws/sessions" ] && session_dir="$ws/sessions"
    _build_pi_command_args "$config_dir" "$session_dir" false
    _run_pi_command "$config_dir"
  )
  return $?
}

_session_first_prompt() {
  local file="$1" max_chars="${2:-80}"
  local line prompt
  line=$(grep -m1 '"role":"user"' "$file" 2>/dev/null) || return 0
  # Extract text after "text":" up to max_chars, handling JSON escapes
  prompt=$(printf '%s' "$line" | sed 's/.*"text":"//; s/"}].*//' | sed 's/\\n/ /g; s/\\t/ /g; s/\\"/"/g; s/\\\\/ /g' | cut -c1-"$max_chars")
  if [ ${#prompt} -ge "$max_chars" ]; then
    prompt="${prompt}…"
  fi
  printf '%s' "$prompt"
}

_cwd_to_session_dir() {
  local cwd="$1"
  local encoded
  encoded="${cwd#/}"
  encoded="${encoded//\//-}"
  printf -- '--%s--' "$encoded"
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
    local base ts prompt session_file
    base=$(basename "$d")
    ts="${base%%--*}"
    prompt=""
    session_file=$(find "$d" -maxdepth 3 -name '*.jsonl' -type f 2>/dev/null | sort | head -1)
    if [ -n "$session_file" ]; then
      prompt=$(_session_first_prompt "$session_file" 60)
    fi
    if [ -n "$prompt" ]; then
      printf '  %-22s  %s\n' "$ts" "$prompt"
    else
      printf '  %-22s\n' "$ts"
    fi
  done
}

_insitu_list() {
  local name="$1" config_dir="$2"
  local sessions_root="$config_dir/sessions"
  local cwd_dir
  cwd_dir="$sessions_root/$(_cwd_to_session_dir "$PWD")"
  if [ ! -d "$cwd_dir" ] || [ -z "$(ls -A "$cwd_dir" 2>/dev/null)" ]; then
    echo "No sessions for $name in $PWD"
    return 0
  fi
  echo "Sessions for $name ($PWD):"
  for f in "$cwd_dir"/*.jsonl; do
    [ -f "$f" ] || continue
    local base ts prompt
    base=$(basename "$f" .jsonl)
    # Filename: 2026-04-15T20-18-33-299Z_<uuid>
    ts="${base%%_*}"
    # Strip milliseconds+Z: 2026-04-15T20-18-33
    ts="${ts%-*}"
    # 2026-04-15T20-18-33 → 2026-04-15 20:18:33
    ts="${ts/T/ }"
    ts=$(printf '%s' "$ts" | sed 's/\(.*\) \(..\)-\(..\)-\(..\)/\1 \2:\3:\4/')
    prompt=$(_session_first_prompt "$f" 60)
    if [ -n "$prompt" ]; then
      printf '  %-22s  %s\n' "$ts" "$prompt"
    else
      printf '  %-22s\n' "$ts"
    fi
  done
}

_workspace_resume() {
  local name="$1" exact="${2:-}" target selected
  local paths=()
  if [ -n "$exact" ]; then
    target=$(_resolve_workspace_exact "$name" "$exact") || return $?
  else
    while IFS= read -r selected; do
      [ -n "$selected" ] && paths+=("$selected")
    done < <(_collect_agent_workspaces "$name")
    if [ ${#paths[@]} -eq 0 ]; then
      echo "No workspaces to resume for $name" >&2
      return 1
    fi
    target=$(_pick_workspace "Workspaces for $name:" "${paths[@]}") || return $?
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

