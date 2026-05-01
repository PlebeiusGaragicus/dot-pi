# dotpi models — inspect and repair model defaults and agent overrides.
# Sourced by the dotpi dispatcher — do not execute directly.

command -v jq &>/dev/null || {
  echo "Error: 'jq' is required. Install it first."
  exit 1
}

defaults_file="$DOT_PI_DIR/model-defaults"
write_model_defaults_file "$defaults_file"

models_file="$(resolve_models_file)"
all_models=()
if [ -f "$models_file" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && all_models+=("$line")
  done < <(list_available_model_ids "$models_file")
fi

role_names=(DEFAULT_AGENTIC_MODEL DEFAULT_FAST_MODEL DEFAULT_VLM_MODEL)

model_id_exists() {
  local model="$1" candidate
  [ -n "$model" ] || return 1
  for candidate in "${all_models[@]}"; do
    [ "$candidate" = "$model" ] && return 0
  done
  return 1
}

write_model_defaults() {
  local values=("$@")
  {
    echo "# Local fallback model aliases used by pi-args files."
    echo "# Leave a value empty to let pi fall back to its settings.json default."
    local i
    for i in "${!role_names[@]}"; do
      echo "export ${role_names[$i]}=\"\${${role_names[$i]}:-${values[$i]}}\""
    done
  } > "$defaults_file"
}

configure_global_defaults() {
  if [ ${#all_models[@]} -eq 0 ]; then
    echo "No models found in $models_file"
    echo "Run 'dotpi setup' first to configure providers/models."
    echo ""
    return 0
  fi

  local role_vals=() role cur
  for role in "${role_names[@]}"; do
    cur="$(read_export_var "$defaults_file" "$role")"
    role_vals+=("$(select_model_id "$role" "$cur" "${all_models[@]}")")
    echo ""
  done
  write_model_defaults "${role_vals[@]}"
  echo "Wrote $defaults_file"
  echo ""
}

detect_config_role() {
  local dir="$1" pi_args="$dir/pi-args" line value env_name expect_next=false
  [ -f "$pi_args" ] || return 1
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    value=""
    if [ "$expect_next" = true ]; then
      value="$line"
      expect_next=false
    elif [[ "$line" == --model[[:space:]]* ]]; then
      value="${line#--model}"
      value="${value#"${value%%[![:space:]]*}"}"
    elif [ "$line" = "--model" ]; then
      expect_next=true
      continue
    fi
    [ -n "$value" ] || continue
    env_name="${value#\$}"
    env_name="${env_name#\{}"
    env_name="${env_name%\}}"
    for role in "${role_names[@]}"; do
      [ "$env_name" = "$role" ] && printf '%s\n' "$role" && return 0
    done
  done < "$pi_args"
  return 1
}

config_label() {
  local dir="$1"
  if [[ "$dir" == "$DOT_PI_DIR/"* ]]; then
    printf '%s\n' "${dir#"$DOT_PI_DIR/"}"
  else
    printf '%s\n' "$dir"
  fi
}

collect_model_configs() {
  local dir role
  for dir in "$DOT_PI_DIR"/agents/* "$DOT_PI_DIR"/subagents/* "$DOT_PI_DIR"/agents/*/agents/*; do
    [ -d "$dir" ] || continue
    role="$(detect_config_role "$dir" 2>/dev/null || true)"
    [ -n "$role" ] || continue
    printf '%s\t%s\n' "$dir" "$role"
  done | sort -u
}

read_agent_override() {
  local file="$1/.model" line
  [ -f "$file" ] || return 0
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line#"${line%%[![:space:]]*}"}"
    line="${line%"${line##*[![:space:]]}"}"
    [[ -z "$line" || "$line" == \#* ]] && continue
    printf '%s\n' "$line"
    return 0
  done < "$file"
}

show_model_report() {
  echo "Model configuration"
  echo "==================="
  echo ""
  echo "models.json: $models_file"
  echo ""
  echo "Available models:"
  if [ ${#all_models[@]} -eq 0 ]; then
    echo "  (none)"
  else
    local model
    for model in "${all_models[@]}"; do
      echo "  $model"
    done
  fi
  echo ""
  echo "Global defaults:"
  local role value
  for role in "${role_names[@]}"; do
    value="$(read_export_var "$defaults_file" "$role")"
    if [ -n "$value" ] && ! model_id_exists "$value"; then
      echo "  $role: $value  [STALE]"
    else
      echo "  $role: ${value:-(unset)}"
    fi
  done
  echo ""
  echo "Agent overrides:"
  local rows=() row dir cfg_role override label
  while IFS=$'\t' read -r dir cfg_role; do
    [ -n "$dir" ] || continue
    override="$(read_agent_override "$dir")"
    [ -n "$override" ] || continue
    label="$(config_label "$dir")"
    if model_id_exists "$override"; then
      rows+=("  $label (.model, $cfg_role): $override")
    else
      rows+=("  $label (.model, $cfg_role): $override  [STALE]")
    fi
  done < <(collect_model_configs)
  if [ ${#rows[@]} -eq 0 ]; then
    echo "  (none)"
  else
    for row in "${rows[@]}"; do
      echo "$row"
    done
  fi
  echo ""
  local settings="$DOT_PI_DIR/shared/settings.json" settings_model
  if [ -f "$settings" ]; then
    settings_model=$(jq -r 'if (.defaultProvider and .defaultModel) then "\(.defaultProvider)/\(.defaultModel)" else "" end' "$settings" 2>/dev/null)
    if [ -n "$settings_model" ] && ! model_id_exists "$settings_model"; then
      echo "Pi settings default: $settings_model  [stale, pi fallback only]"
    elif [ -n "$settings_model" ]; then
      echo "Pi settings default: $settings_model"
    fi
    echo ""
  fi
}

configure_agent_override() {
  if [ ${#all_models[@]} -eq 0 ]; then
    echo "No models found in $models_file"
    echo "Run 'dotpi setup' first to configure providers/models."
    echo ""
    return 0
  fi

  local dirs=() roles=() dir role i choice current selected
  while IFS=$'\t' read -r dir role; do
    [ -n "$dir" ] || continue
    dirs+=("$dir")
    roles+=("$role")
  done < <(collect_model_configs)

  if [ ${#dirs[@]} -eq 0 ]; then
    echo "No agent or subagent configs with DEFAULT_* model aliases found."
    echo ""
    return 0
  fi

  echo "Select an agent or subagent override:"
  for i in "${!dirs[@]}"; do
    current="$(read_agent_override "${dirs[$i]}")"
    printf "  %d) %-45s %s %s\n" "$((i + 1))" "$(config_label "${dirs[$i]}")" "${roles[$i]}" "${current:+(.model: $current)}"
  done
  echo "  q) cancel"
  read -r -p "choice: " choice
  if [ "$choice" = "q" ] || [ "$choice" = "Q" ] || [ -z "$choice" ]; then
    echo ""
    return 0
  fi
  if [[ "$choice" == *[!0-9]* ]] || [ "$choice" -lt 1 ] || [ "$choice" -gt "${#dirs[@]}" ]; then
    echo "Invalid choice."
    echo ""
    return 0
  fi

  dir="${dirs[$((choice - 1))]}"
  current="$(read_agent_override "$dir")"
  selected="$(select_model_id "$(config_label "$dir")" "$current" "${all_models[@]}")"
  if [ -n "$selected" ]; then
    printf '%s\n' "$selected" > "$dir/.model"
    echo "Wrote $dir/.model"
  else
    rm -f "$dir/.model"
    echo "Removed $dir/.model"
  fi
  echo ""
}

if [ "${1:-}" = "--defaults-only" ]; then
  configure_global_defaults
  return 0 2>/dev/null || exit 0
fi

while true; do
  echo ""
  echo "dotpi models"
  echo "============"
  echo ""
  show_model_report
  echo "Actions:"
  echo "  1) Configure global model defaults"
  echo "  2) Set/reset agent or subagent override"
  echo "  q) Quit"
  echo ""
  read -r -p "choice: " action
  case "$action" in
    1) configure_global_defaults ;;
    2) configure_agent_override ;;
    q|Q|"") break ;;
    *) echo "Invalid choice." ;;
  esac
done
