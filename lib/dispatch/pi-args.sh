# pi argument loading, model aliases, and model fall-through filtering.

_load_model_env() {
  local config_dir="$1"
  local file line name value fallback
  _inline_model_defaults=":"
  file="$DOT_PI_DIR/model-defaults"
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^[[:space:]]*export[[:space:]]+([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]] || continue
    name="${BASH_REMATCH[1]}"
    value="${BASH_REMATCH[2]}"
    fallback="${value#\"\$\{${name}:-}"
    if [ "$fallback" != "$value" ]; then
      fallback="${fallback%\}\"}"
      value="$fallback"
    else
      value="${value%\"}"
      value="${value#\"}"
    fi
    if [ -n "${!name:-}" ]; then
      _inline_model_defaults="${_inline_model_defaults}${name}:"
    else
      export "$name=$value"
    fi
  done < "$file"
}

_read_agent_model() {
  local config_dir="$1"
  local model_file="$config_dir/.model"
  local line
  [ -f "$model_file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '%s\n' "$line"
    return 0
  done < "$model_file"
}

_filter_model_flags() {
  local config_dir="$1"
  local out=() arg next agent_model alias_name alias_value
  agent_model="$(_read_agent_model "$config_dir")"
  while [ ${#_pi_args[@]} -gt 0 ]; do
    arg="${_pi_args[0]}"
    _pi_args=("${_pi_args[@]:1}")
    case "$arg" in
      --model)
        next="${_pi_args[0]:-}"
        [ ${#_pi_args[@]} -gt 0 ] && _pi_args=("${_pi_args[@]:1}")
        [ -z "$next" ] && continue
        [[ "$next" == --* ]] && { _pi_args=("$next" "${_pi_args[@]}"); continue; }
        if [[ "$next" == __DOTPI_MODEL_ALIAS__:* ]]; then
          alias_name="${next#__DOTPI_MODEL_ALIAS__:}"
          alias_name="${alias_name%%:*}"
          alias_value="${next#__DOTPI_MODEL_ALIAS__:${alias_name}:}"
          if [[ "$_inline_model_defaults" == *":${alias_name}:"* ]]; then
            next="$alias_value"
          elif [ -n "$agent_model" ]; then
            next="$agent_model"
          else
            next="$alias_value"
          fi
        fi
        [ -z "$next" ] && continue
        out+=("$arg" "$next")
        ;;
      *)
        out+=("$arg")
        ;;
    esac
  done
  if [ ${#out[@]} -gt 0 ]; then
    _pi_args=("${out[@]}")
  else
    _pi_args=()
  fi
}

_load_pi_args() {
  local config_dir="$1" _line _raw_line _alias_name
  _pi_args=()
  _load_model_env "$config_dir"
  if [ -f "$config_dir/pi-args" ]; then
    while IFS= read -r _line || [ -n "$_line" ]; do
      [[ -z "$_line" || "$_line" == \#* ]] && continue
      _raw_line="$_line"
      _line="$(_expand_env_vars "$_line")"
      if [[ "$_raw_line" =~ ^[[:space:]]*\$?\{?(DEFAULT_[A-Z0-9_]+)\}?[[:space:]]*$ ]]; then
        _alias_name="${BASH_REMATCH[1]}"
        _line="__DOTPI_MODEL_ALIAS__:${_alias_name}:${_line}"
      fi
      # shellcheck disable=SC2206  # intentional word-splitting so multi-word flags expand
      _pi_args+=($_line)
    done < "$config_dir/pi-args"
  fi
}

