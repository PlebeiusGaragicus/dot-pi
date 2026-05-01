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

_models_file() {
  if [ -L "$DOT_PI_DIR/shared/models.json" ]; then
    readlink -f "$DOT_PI_DIR/shared/models.json" 2>/dev/null || printf '%s\n' "$DOT_PI_DIR/shared/models.json"
  else
    printf '%s\n' "$DOT_PI_DIR/shared/models.json"
  fi
}

_model_exists() {
  local model="$1" models_file
  models_file="$(_models_file)"
  [ -n "$model" ] || return 1
  [ -f "$models_file" ] || return 1
  command -v jq >/dev/null 2>&1 || return 0
  jq -e --arg full "$model" '
    [
      .providers
      | to_entries[]
      | .key as $provider
      | .value.models[]?
      | "\($provider)/\(.id)"
    ]
    | index($full) != null
  ' "$models_file" >/dev/null 2>&1
}

_list_models_from_config() {
  local models_file
  models_file="$(_models_file)"
  [ -f "$models_file" ] || return 0
  if command -v jq >/dev/null 2>&1; then
    jq -r '.providers | to_entries[] | .key as $p | .value.models[]? | "\($p)/\(.id)"' "$models_file" 2>/dev/null
  fi
}

_write_model_default_value() {
  local key="$1" value="$2" file="$DOT_PI_DIR/model-defaults" tmp line found=false
  [ -f "$file" ] || {
    {
      echo "# Local fallback model aliases used by pi-args files."
      echo "# Leave a value empty to let pi fall back to its settings.json default."
    } > "$file"
  }
  tmp="$(mktemp "${TMPDIR:-/tmp}/dotpi-model-defaults.XXXXXX")"
  while IFS= read -r line || [ -n "$line" ]; do
    if [[ "$line" =~ ^export[[:space:]]+${key}= ]]; then
      printf 'export %s="${%s:-%s}"\n' "$key" "$key" "$value" >> "$tmp"
      found=true
    else
      printf '%s\n' "$line" >> "$tmp"
    fi
  done < "$file"
  if [ "$found" != true ]; then
    printf 'export %s="${%s:-%s}"\n' "$key" "$key" "$value" >> "$tmp"
  fi
  mv "$tmp" "$file"
}

_select_replacement_model() {
  local invalid="$1" source="$2" models=() line choice
  while IFS= read -r line; do
    [ -n "$line" ] && models+=("$line")
  done < <(_list_models_from_config)
  if [ ${#models[@]} -eq 0 ]; then
    echo "No models found in $(_models_file)." >&2
    echo "Run: dotpi setup" >&2
    return 1
  fi

  echo "Model \"$invalid\" from $source was not found in $(_models_file)." >&2
  echo "" >&2
  if command -v pi >/dev/null 2>&1; then
    echo "Available models from pi:" >&2
    pi --list-models >&2 || true
    echo "" >&2
  fi
  echo "Select a replacement model:" >&2
  local i
  for i in "${!models[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${models[$i]}" >&2
  done
  printf "  q) cancel\n" >&2
  read -r -p "choice: " choice
  if [ "$choice" = "q" ] || [ "$choice" = "Q" ] || [ -z "$choice" ]; then
    echo "Run: dotpi models" >&2
    return 1
  fi
  if [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "${#models[@]}" ]; then
    printf '%s\n' "${models[$((choice - 1))]}"
    return 0
  fi
  echo "Invalid choice. Run: dotpi models" >&2
  return 1
}

_repair_missing_model() {
  local model="$1" source="$2" replacement
  if [ "$_cli_print" = true ] || [ ! -t 0 ] || [ ! -t 1 ]; then
    echo "Model \"$model\" from $source was not found in $(_models_file)." >&2
    echo "Run: dotpi models" >&2
    return 1
  fi

  case "$_dispatch_model_source" in
    agent-model)
      replacement="$(_select_replacement_model "$model" "$source")" || return $?
      printf '%s\n' "$replacement" > "$_dispatch_model_source_path"
      echo "Updated $_dispatch_model_source_path" >&2
      printf '%s\n' "$replacement"
      ;;
    model-defaults)
      replacement="$(_select_replacement_model "$model" "$source")" || return $?
      _write_model_default_value "$_dispatch_model_source_key" "$replacement"
      export "$_dispatch_model_source_key=$replacement"
      echo "Updated $DOT_PI_DIR/model-defaults" >&2
      printf '%s\n' "$replacement"
      ;;
    *)
      echo "Model \"$model\" from $source was not found in $(_models_file)." >&2
      echo "Run: dotpi models" >&2
      return 1
      ;;
  esac
}

_validate_or_repair_model() {
  local model="$1" source="$2" replacement
  [ -n "$model" ] || return 0
  _model_exists "$model" && return 0
  replacement="$(_repair_missing_model "$model" "$source")" || return $?
  printf '%s\n' "$replacement"
}

_filter_model_flags() {
  local config_dir="$1"
  local out=() arg next agent_model alias_name alias_value source replacement
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
        _dispatch_model_source="literal-pi-args"
        _dispatch_model_source_path="$config_dir/pi-args"
        _dispatch_model_source_key=""
        source="$config_dir/pi-args"
        if [[ "$next" == __DOTPI_MODEL_ALIAS__:* ]]; then
          alias_name="${next#__DOTPI_MODEL_ALIAS__:}"
          alias_name="${alias_name%%:*}"
          alias_value="${next#__DOTPI_MODEL_ALIAS__:${alias_name}:}"
          if [[ "$_inline_model_defaults" == *":${alias_name}:"* ]]; then
            next="$alias_value"
            _dispatch_model_source="inline-env"
            _dispatch_model_source_path=""
            _dispatch_model_source_key="$alias_name"
            source="inline env $alias_name"
          elif [ -n "$agent_model" ]; then
            next="$agent_model"
            _dispatch_model_source="agent-model"
            _dispatch_model_source_path="$config_dir/.model"
            _dispatch_model_source_key=""
            source="$config_dir/.model"
          else
            next="$alias_value"
            _dispatch_model_source="model-defaults"
            _dispatch_model_source_path="$DOT_PI_DIR/model-defaults"
            _dispatch_model_source_key="$alias_name"
            source="$DOT_PI_DIR/model-defaults ($alias_name)"
          fi
        fi
        [ -z "$next" ] && continue
        replacement="$(_validate_or_repair_model "$next" "$source")" || return $?
        [ -n "$replacement" ] && next="$replacement"
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

