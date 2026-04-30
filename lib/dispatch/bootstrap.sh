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

_source_bootstrap() {
  local config_dir="$1" phase="$2" ws_path="${3:-}" agent_name="${4:-$AGENT_NAME}"
  local file log_dir status cwd shell_opts show_bootstrap_output bootstrap_output_file
  file="$(_bootstrap_file "$config_dir")"
  [ -n "$file" ] || return 0

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
  {
    printf '[%s] bootstrap start: %s phase=%s cwd=%s\n' "$(date -Iseconds)" "$file" "$phase" "$(pwd)"
  } >> "$BOOTSTRAP_LOG"

  show_bootstrap_output=false
  if [ "${_cli_print:-false}" != true ] && [ "${_cli_has_prompt:-false}" != true ] && [ -t 1 ]; then
    show_bootstrap_output=true
    echo "Bootstrap: $BOOTSTRAP_LOG"
  fi
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
  if [ "$show_bootstrap_output" = true ]; then
    cat "$bootstrap_output_file"
  fi
  rm -f "$bootstrap_output_file"
  {
    printf '[%s] bootstrap end: status=%s\n' "$(date -Iseconds)" "$status"
  } >> "$BOOTSTRAP_LOG"
  if [ "$status" -ne 0 ]; then
    echo "Bootstrap failed for $agent_name (exit $status). See $BOOTSTRAP_LOG" >&2
    return "$status"
  fi
}

