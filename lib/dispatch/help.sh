# CLI help rendering.

_show_help() {
  local config_dir="$1"
  local usage="$config_dir/USAGE.md"
  local readme="$config_dir/README.md"
  # USAGE.md is the canonical CLI reference (man-page style plain text).
  if [ -f "$usage" ]; then
    cat "$usage"
    exit 0
  fi
  _show_agent_usage "$config_dir"
  echo ""
  if [ -f "$readme" ]; then
    if command -v glow &>/dev/null; then
      glow -p "$readme"
    elif command -v bat &>/dev/null; then
      bat --style=plain --paging=never "$readme"
    else
      cat "$readme"
    fi
  else
    echo "No USAGE.md or README.md for $AGENT_NAME"
    echo "  config: $config_dir"
    echo "  Add USAGE.md (man-style CLI help) or README.md (human overview)."
  fi
  exit 0
}

_show_agent_usage() {
  local config_dir="$1" is_workspace=false
  _is_workspace_agent "$config_dir" && is_workspace=true
  echo "Usage:"
  echo "  $AGENT_NAME [help|usage|-h|--help]"
  echo "  $AGENT_NAME"
  echo "  $AGENT_NAME - <prompt>         # initial prompt, then interactive"
  echo "  $AGENT_NAME -p <prompt>        # print final reply and exit"
  echo "  $AGENT_NAME -p -v <prompt>     # print final reply plus progress"
  if [ "$is_workspace" = true ]; then
    echo "  $AGENT_NAME -n <name> - <prompt>"
    echo "  $AGENT_NAME --name <name> - <prompt>"
    echo "  $AGENT_NAME -p -n <name> <prompt>"
    echo "  $AGENT_NAME ls"
    echo "  $AGENT_NAME resume [workspace-prefix]"
    echo "  $AGENT_NAME resume [workspace-prefix] - <prompt>"
    echo "  $AGENT_NAME resume [workspace-prefix] -p <prompt>"
  fi
}

