# Main dispatch routing.

_list_available() {
  echo "Available agents:" >&2
  printf '  %-20s  %-8s  %s\n' "name" "kind" "mode" >&2
  {
    for d in "$DOT_PI_DIR"/agents/*/; do
      [ -d "$d" ] || continue
      local name mode kind
      name=$(basename "$d")
      mode=$(_is_workspace_agent "$d" && echo workspace || echo in-situ)
      kind=$([ -e "$d/extensions/agent-orchestrator/index.ts" ] && echo mas || echo agent)
      printf '%s\t%s\t%s\n' "$name" "$kind" "$mode"
    done
  } | sort -t $'\t' -k1,1 | while IFS=$'\t' read -r name kind mode; do
    printf '  %-20s  %-8s  %s\n' "$name" "$kind" "$mode" >&2
  done
}

_dispatch_main() {
# Special dispatch: resume
if [ "$AGENT_NAME" = "resume" ]; then
  _resume_global "$@"
  exit $?
fi

# Special dispatch: dispatch-agent invoked directly (not via symlink)
if [ "$AGENT_NAME" = "dispatch-agent" ]; then
  echo "Usage: invoke via an agent symlink (e.g. lm, recon, blog)" >&2
  echo ""
  _list_available
  exit 1
fi

# Resolve config directory
config_dir=""
if [ -d "$DOT_PI_DIR/agents/$AGENT_NAME" ]; then
  config_dir="$DOT_PI_DIR/agents/$AGENT_NAME"
else
  echo "Unknown agent: $AGENT_NAME" >&2
  _list_available
  exit 1
fi

# Parse dotpi-owned agent command syntax before invoking pi.
if ! _parse_agent_cli "$config_dir" "$@"; then
  echo "Error: $_cli_error" >&2
  echo "" >&2
  _show_agent_usage "$config_dir" >&2
  exit 1
fi

if [ "$_cli_action" = "help" ]; then
  _show_help "$config_dir"
  exit 0
fi

_read_stdin_prompt_if_needed

if [ "$_cli_print" = true ] && [ "$_cli_has_prompt" = false ]; then
  echo "Error: -p/--print requires a prompt" >&2
  echo "" >&2
  _show_agent_usage "$config_dir" >&2
  exit 1
fi

# Load default CLI flags from pi-args. User argv is dotpi syntax, not raw pi
# passthrough, so model filtering only considers configured defaults.
_load_pi_args "$config_dir"

# Dispatch: workspace or in-situ
if _is_workspace_agent "$config_dir"; then
  case "$_cli_action" in
    ls)
      _workspace_list "$AGENT_NAME"
      exit $?
      ;;
    resume)
      if [ "$_cli_print" = true ]; then
        _workspace_resume "$AGENT_NAME" "$_cli_resume_prefix" | _json_filter
        exit ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
      else
        _workspace_resume "$AGENT_NAME" "$_cli_resume_prefix"
        exit $?
      fi
      ;;
    launch)
      if [ "$_cli_print" = true ]; then
        _workspace_launch "$AGENT_NAME" "$config_dir" | _json_filter
        exit ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
      else
        _workspace_launch "$AGENT_NAME" "$config_dir"
        exit $?
      fi
      ;;
  esac
else
  _filter_model_flags "$config_dir"
  _in_situ_args=()
  [ ${#_pi_args[@]} -gt 0 ] && _in_situ_args+=("${_pi_args[@]}")
  [ "$_cli_print" = true ] && _in_situ_args+=(--mode json)
  _build_prompt_args
  [ ${#_prompt_args[@]} -gt 0 ] && _in_situ_args+=("${_prompt_args[@]}")
  if [ "$_cli_print" = true ]; then
    _source_bootstrap "$config_dir" "in-situ" "" "$AGENT_NAME"
    _run_pi_with_args_array "$config_dir" _in_situ_args < /dev/null | _json_filter
    exit ${PIPESTATUS[0]:-${pipestatus[1]:-$?}}
  else
    _source_bootstrap "$config_dir" "in-situ" "" "$AGENT_NAME"
    _run_pi_with_args_array "$config_dir" _in_situ_args
    exit $?
  fi
fi
}
