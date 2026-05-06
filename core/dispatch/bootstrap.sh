# Agent bootstrap.sh handling.

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

_source_bootstrap() {
  local config_dir="$1" phase="$2" ws_path="${3:-}" agent_name="${4:-$AGENT_NAME}"
  local agent_file log_dir has_hooks=false

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

  agent_file="$(_bootstrap_file "$config_dir")"
  [ -n "$agent_file" ] && has_hooks=true

  [ "$has_hooks" = true ] || return 0

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
}
