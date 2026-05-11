# CLI help rendering.

_show_help() {
  local config_dir="$1"
  local usage="$config_dir/USAGE.md"
  # USAGE.md is the canonical CLI reference (man-page style plain text).
  if [ -f "$usage" ]; then
    cat "$usage"
    exit 0
  fi
  echo "$AGENT_NAME does not have USAGE.md" >&2
  echo "  config: $config_dir" >&2
  exit 1
}

_show_agent_usage() {
  local config_dir="$1"
  echo "Usage:"
  echo "  $AGENT_NAME [help|usage|-h|--help]"
  echo "  $AGENT_NAME"
  echo "  $AGENT_NAME - <prompt>         # initial prompt, then interactive"
  echo "  $AGENT_NAME -p <prompt>        # print final reply and exit"
  echo "  $AGENT_NAME -p -v <prompt>     # print final reply plus progress"
  echo "  $AGENT_NAME ls                 # list sessions"
}

