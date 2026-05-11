# Main dispatch routing.

_list_available() {
  echo "Available agents:" >&2
  printf '  %-20s  %-8s\n' "name" "kind" >&2
  {
    for d in "$DOT_PI_DIR"/agents/*/; do
      [ -d "$d" ] || continue
      local name kind
      name=$(basename "$d")
      kind=$([ -e "$d/extensions/agent-orchestrator/index.ts" ] || [ -e "$d/extensions/top-level-agent-orchestrator/index.ts" ] && echo mas || echo agent)
      printf '%s\t%s\n' "$name" "$kind"
    done
  } | sort -t $'\t' -k1,1 | while IFS=$'\t' read -r name kind; do
    printf '  %-20s  %-8s\n' "$name" "$kind" >&2
  done
}

_cwd_to_session_dir() {
  local cwd="$1" encoded
  encoded="${cwd#/}"
  encoded="${encoded//\//-}"
  printf -- '--%s--' "$encoded"
}

_agent_session_dir() {
  local name="$1"
  printf '%s/%s/sessions/%s\n' "$DOT_PI_OVERLAY" "$name" "$(_cwd_to_session_dir "$PWD")"
}

_session_first_prompt() {
  local file="$1" max_chars="${2:-80}"
  local line prompt
  line=$(grep -m1 '"role":"user"' "$file" 2>/dev/null) || return 0
  prompt=$(printf '%s' "$line" | sed 's/.*"text":"//; s/"}].*//' | sed 's/\\n/ /g; s/\\t/ /g; s/\\"/"/g; s/\\\\/ /g' | cut -c1-"$max_chars")
  if [ ${#prompt} -ge "$max_chars" ]; then
    prompt="${prompt}..."
  fi
  printf '%s' "$prompt"
}

_insitu_list() {
  local name="$1" session_dir
  session_dir="$(_agent_session_dir "$name")"
  if [ ! -d "$session_dir" ] || [ -z "$(ls -A "$session_dir" 2>/dev/null)" ]; then
    echo "No sessions for $name in $PWD"
    return 0
  fi
  echo "Sessions for $name ($PWD):"
  for f in "$session_dir"/*.jsonl; do
    [ -f "$f" ] || continue
    local base ts prompt
    base=$(basename "$f" .jsonl)
    ts="${base%%_*}"
    ts="${ts%-*}"
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

_dispatch_main() {
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

# Dispatch: in-situ with overlay-backed sessions
case "$_cli_action" in
  ls)
    _insitu_list "$AGENT_NAME"
    exit $?
    ;;
  *)
    session_dir="$(_agent_session_dir "$AGENT_NAME")"
    mkdir -p "$session_dir"
    _source_bootstrap "$config_dir" "in-situ" "$session_dir" "$AGENT_NAME"
    _build_pi_command_args "$config_dir" "$session_dir"
    _run_pi_command "$config_dir"
    exit $?
    ;;
esac
}
