# Agent and skill bootstrap.sh handling.

_bootstrap_declares_workspace() {
  local config_dir="$1" file line value
  file="$(_bootstrap_file "$config_dir")"
  [ -n "$file" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="$(_trim "$line")"
    [[ -z "$line" || "$line" == \#* ]] && continue
    if [[ "$line" =~ ^export[[:space:]]+(.+)$ ]]; then
      line="$(_trim "${BASH_REMATCH[1]}")"
    fi
    [[ "$line" =~ ^WORKSPACE_AGENT=(.*)$ ]] || continue
    value="$(_trim "${BASH_REMATCH[1]}")"
    if [[ "$value" == \"*\" && "$value" == *\" ]]; then
      value="${value:1:${#value}-2}"
    elif [[ "$value" == \'*\' && "$value" == *\' ]]; then
      value="${value:1:${#value}-2}"
    fi
    [ "$value" = "1" ] && return 0
  done < "$file"
  return 1
}

_is_workspace_agent() {
  local config_dir="$1"
  _bootstrap_declares_workspace "$config_dir"
}

_source_one_bootstrap() {
  local file="$1" label="$2"
  local status cwd shell_opts bootstrap_output_file
  {
    printf '[%s] bootstrap start: %s phase=%s cwd=%s\n' \
      "$(date -Iseconds)" "$label" "$DOTPI_BOOTSTRAP_PHASE" "$(pwd)"
  } >> "$BOOTSTRAP_LOG"
  cwd="$(pwd)"
  shell_opts="$(set +o)"
  bootstrap_output_file="$(mktemp "${TMPDIR:-/tmp}/dotpi-bootstrap.XXXXXX")"
  if . "$file" > "$bootstrap_output_file" 2>&1; then
    status=0
  else
    status=$?
  fi
  eval "$shell_opts"
  cd "$cwd"
  cat "$bootstrap_output_file" >> "$BOOTSTRAP_LOG"
  if [ "$_bootstrap_show_output" = true ]; then
    cat "$bootstrap_output_file"
  fi
  rm -f "$bootstrap_output_file"
  {
    printf '[%s] bootstrap end: %s status=%s\n' "$(date -Iseconds)" "$label" "$status"
  } >> "$BOOTSTRAP_LOG"
  if [ "$status" -ne 0 ]; then
    echo "Bootstrap failed ($label, exit $status). See $BOOTSTRAP_LOG" >&2
    return "$status"
  fi
}

_collect_skill_bootstraps() {
  local config_dir="$1" skill_dir skill_name
  for skill_dir in "$config_dir"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    [ -f "$skill_dir/scripts/bootstrap.sh" ] || continue
    skill_name=$(basename "$skill_dir")
    printf '%s\t%s\n' "$skill_name" "$skill_dir/scripts/bootstrap.sh"
  done | sort -t $'\t' -k1,1
}

_source_bootstrap() {
  local config_dir="$1" phase="$2" ws_path="${3:-}" agent_name="${4:-$AGENT_NAME}"
  local agent_file log_dir has_hooks=false

  agent_file="$(_bootstrap_file "$config_dir")"
  [ -n "$agent_file" ] && has_hooks=true

  local skill_hooks=() skill_line
  while IFS= read -r skill_line; do
    [ -n "$skill_line" ] && skill_hooks+=("$skill_line") && has_hooks=true
  done < <(_collect_skill_bootstraps "$config_dir")

  [ "$has_hooks" = true ] || return 0

  export DOT_PI_DIR
  export AGENT_NAME="$agent_name"
  export AGENT_DIR="$config_dir"
  export DOTPI_BOOTSTRAP_PHASE="$phase"
  if _bootstrap_declares_workspace "$config_dir"; then
    export WORKSPACE_AGENT=1
  else
    export WORKSPACE_AGENT=0
  fi
  if [ -n "$ws_path" ]; then
    export WORKSPACE_DIR="$ws_path"
    export BOOTSTRAP_LOG="${BOOTSTRAP_LOG:-$WORKSPACE_DIR/bootstrap.log}"
  else
    unset WORKSPACE_DIR
    mkdir -p "$config_dir/sessions"
    export BOOTSTRAP_LOG="${BOOTSTRAP_LOG:-$config_dir/sessions/bootstrap.log}"
  fi

  log_dir="$(dirname "$BOOTSTRAP_LOG")"
  mkdir -p "$log_dir"
  : > "$BOOTSTRAP_LOG"

  _bootstrap_show_output=false
  if [ "${_cli_print:-false}" != true ] && [ "${_cli_has_prompt:-false}" != true ] && [ -t 1 ]; then
    _bootstrap_show_output=true
    echo "Bootstrap: $BOOTSTRAP_LOG"
  fi

  if [ -n "$agent_file" ]; then
    _source_one_bootstrap "$agent_file" "agent $agent_name" || return $?
  fi

  local skill_name skill_file
  for skill_line in ${skill_hooks[@]+"${skill_hooks[@]}"}; do
    skill_name="${skill_line%%	*}"
    skill_file="${skill_line#*	}"
    _source_one_bootstrap "$skill_file" "skill $skill_name" || return $?
  done
}
