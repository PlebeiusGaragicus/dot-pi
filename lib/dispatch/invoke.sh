# pi process invocation and JSON event stream filtering.

_pi() {
  PI_SKIP_VERSION_CHECK=1 PI_OFFLINE=1 command pi "$@"
}

_run_pi_with_args_array() {
  local config_dir="$1" array_name="$2" count
  eval "count=\${#${array_name}[@]}"
  if [ "${DOTPI_DISPATCH_CAPTURE_PI:-}" = "1" ]; then
    printf 'PI_CODING_AGENT_DIR=%s\n' "$config_dir" >&2
    printf 'ARGV' >&2
    if [ "$count" -gt 0 ]; then
      local _arg
      eval "for _arg in \"\${${array_name}[@]}\"; do printf '\t%s' \"\$_arg\" >&2; done"
    fi
    printf '\n' >&2
    return 0
  fi
  if [ "$count" -gt 0 ]; then
    eval "PI_CODING_AGENT_DIR=\"\$config_dir\" _pi \"\${${array_name}[@]}\""
  else
    PI_CODING_AGENT_DIR="$config_dir" _pi
  fi
}

_json_filter() {
  local turn=0 final_text=""
  while IFS= read -r line; do
    local type
    type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null) || continue
    case "$type" in
      turn_start)
        turn=$((turn + 1))
        ;;
      tool_execution_start)
        local tool_name
        tool_name=$(printf '%s' "$line" | jq -r '.toolName // "?"')
        [ "${_cli_verbose:-false}" = true ] && printf '[turn %d] tool: %s\n' "$turn" "$tool_name" >&2
        ;;
      tool_execution_end)
        local tool_name is_err
        tool_name=$(printf '%s' "$line" | jq -r '.toolName // "?"')
        is_err=$(printf '%s' "$line" | jq -r '.isError // false')
        if [ "$_cli_verbose" = true ] && [ "$is_err" = "true" ]; then
          printf '[turn %d] tool: %s ERROR\n' "$turn" "$tool_name" >&2
        fi
        ;;
      message_end)
        local role text
        role=$(printf '%s' "$line" | jq -r '.message.role // empty')
        if [ "$role" = "assistant" ]; then
          text=$(printf '%s' "$line" | jq -r '
            [.message.content[]? | select(.type == "text") | .text]
            | join("\n")' 2>/dev/null)
          [ -n "$text" ] && final_text="$text"
        fi
        ;;
      agent_end)
        [ "${_cli_verbose:-false}" = true ] && printf '[agent done]\n' >&2
        ;;
    esac
  done
  [ -n "$final_text" ] && printf '%s\n' "$final_text"
}

