# Shared helpers for dotpi subcommands.
# Sourced by the dotpi dispatcher — do not execute directly.

# shellcheck disable=SC2034
SHARED_DIR="$DOT_PI_DIR/shared"

link_extension_bundle() {
  local bundle_dir="$1" target_dir="$2" rel_prefix="$3" ext name
  [ -d "$bundle_dir" ] || return 0
  mkdir -p "$target_dir"
  for ext in "$bundle_dir"/*; do
    [ -e "$ext" ] || [ -L "$ext" ] || continue
    name=$(basename "$ext")
    if [ -e "$target_dir/$name" ] && [ ! -L "$target_dir/$name" ]; then
      echo "sync: keeping existing non-symlink extension $target_dir/$name" >&2
      continue
    fi
    [ -L "$target_dir/$name" ] && rm "$target_dir/$name"
    ln -s "$rel_prefix/$name" "$target_dir/$name"
  done
}

write_model_defaults_file() {
  local path="$1"
  [ -e "$path" ] && return 0
  cat > "$path" <<'EOF'
# Local fallback model aliases used by pi-args files.
# Leave a value empty to let pi fall back to its settings.json default.
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
EOF
}

resolve_models_file() {
  local dotpi_models="$SHARED_DIR/models.json"
  local system_models="$HOME/.pi/agent/models.json"
  if [ -L "$dotpi_models" ]; then
    readlink -f "$dotpi_models" 2>/dev/null || echo "$dotpi_models"
  elif [ -f "$system_models" ]; then
    echo "$system_models"
  else
    mkdir -p "$HOME/.pi/agent"
    echo "$system_models"
  fi
}

read_export_var() {
  local file="$1" varname="$2" value expect_prefix
  if [ -f "$file" ]; then
    value=$(sed -nE "s/^export[[:space:]]+${varname}=(.*)$/\1/p" "$file" | head -1)
    expect_prefix=$(printf '"${%s:-' "$varname")
    if [[ "$value" == "$expect_prefix"* ]]; then
      value="${value#"$expect_prefix"}"
      value="${value%\}\"}"
    fi
    printf '%s\n' "$value"
  fi
}

list_available_model_ids() {
  local models_file="${1:-$(resolve_models_file)}"
  [ -f "$models_file" ] || return 0
  jq -r '.providers | to_entries[] | .key as $p | .value.models[]? | "\($p)/\(.id)"' "$models_file" 2>/dev/null
}

select_model_id() {
  local role="$1" current="$2"
  shift 2
  local models=("$@")
  local hint=""
  [ -n "$current" ] && hint=" (current: $current)"
  echo "  $role$hint" >&2
  local i
  for i in "${!models[@]}"; do
    local marker="  "
    [ "${models[$i]}" = "$current" ] && marker="> "
    printf "    %s%d) %s\n" "$marker" "$((i + 1))" "${models[$i]}" >&2
  done
  printf "    %s%d) %s\n" "  " "$((${#models[@]} + 1))" "(unset / use pi default)" >&2
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

resolve_dir() {
  local name="$1"
  if [ -d "$DOT_PI_DIR/agents/$name" ]; then
    echo "$DOT_PI_DIR/agents/$name"
  else
    return 1
  fi
}

agent_declares_workspace() {
  local dir="$1" line value
  local file="$dir/bootstrap.sh"
  [ -f "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" =~ ^export[[:space:]]+(.+)$ ]]; then
      line="${BASH_REMATCH[1]}"
      line="${line#"${line%%[![:space:]]*}"}"
      line="${line%"${line##*[![:space:]]}"}"
    fi
    [[ "$line" =~ ^WORKSPACE_AGENT=(.*)$ ]] || continue
    value="${BASH_REMATCH[1]}"
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
    [ "$value" = "1" ] && return 0
  done < "$file"
  return 1
}
