# Agent bootstrap.sh handling. Bootstrap files are ordinary in-situ launch hooks;
# workspace mode is no longer part of the supported dispatch model.

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
  local config_dir="$1" phase="$2" session_dir="${3:-}" agent_name="${4:-$AGENT_NAME}"
  local agent_file log_dir has_hooks=false

  export DOT_PI_DIR
  export DOT_PI_OVERLAY
  export AGENT_NAME="$agent_name"
  export AGENT_DIR="$config_dir"
  export DOTPI_BOOTSTRAP_PHASE="$phase"
  unset WORKSPACE_AGENT
  unset WORKSPACE_DIR
  [ -n "$session_dir" ] || session_dir="$DOT_PI_OVERLAY/$agent_name/sessions"
  mkdir -p "$session_dir"
  export BOOTSTRAP_LOG="${BOOTSTRAP_LOG:-$session_dir/bootstrap.log}"

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
