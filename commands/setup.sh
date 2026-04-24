# dotpi setup — interactive setup wizard (providers, models, roles)
# Sourced by the dotpi dispatcher — do not execute directly.

_setup_mask() {
  local val="$1"
  if [ -z "$val" ]; then
    echo "(none)"
  elif [ ${#val} -le 8 ]; then
    echo "****"
  else
    echo "${val:0:4}****${val: -2}"
  fi
}

_setup_read_env_var() {
  local file="$1" varname="$2"
  if [ -f "$file" ]; then
    grep "^export ${varname}=" "$file" 2>/dev/null | head -1 | sed "s/^export ${varname}=//"
  fi
}

_setup_select_model() {
  local role="$1" current="$2"
  shift 2
  local models=("$@")

  local hint=""
  [ -n "$current" ] && hint=" (current: $current)"
  echo "  $role$hint"

  local i
  for i in "${!models[@]}"; do
    local marker="  "
    [ "${models[$i]}" = "$current" ] && marker="> "
    printf "    %s%d) %s\n" "$marker" "$((i + 1))" "${models[$i]}"
  done
  printf "    %s%d) %s\n" "  " "$((${#models[@]} + 1))" "(skip)"

  local choice
  read -r -p "    choice [Enter=keep]: " choice
  if [ -z "$choice" ]; then
    echo "$current"
  elif [ "$choice" = "-" ]; then
    echo ""
  elif [ "$choice" -ge 1 ] 2>/dev/null && [ "$choice" -le "${#models[@]}" ]; then
    echo "${models[$((choice - 1))]}"
  elif [ "$choice" -eq "$((${#models[@]} + 1))" ] 2>/dev/null; then
    echo ""
  else
    echo >&2 "    invalid choice, keeping current"
    echo "$current"
  fi
}

# ── dependency check ─────────────────────────────────────────────────────────

for _cmd in jq curl; do
  command -v "$_cmd" &>/dev/null || {
    echo "Error: '$_cmd' is required. Install it first."
    exit 1
  }
done

MODELS_FILE="$SHARED_DIR/models.json"
mkdir -p "$SHARED_DIR"

echo ""
echo "dot-pi setup"
echo "============"
echo ""

# ── Step 1: Provider management ──────────────────────────────────────────────

_provider_count() {
  if [ -f "$MODELS_FILE" ]; then
    jq -r '.providers | length // 0' "$MODELS_FILE" 2>/dev/null || echo 0
  else
    echo 0
  fi
}

_list_providers() {
  jq -r '.providers | to_entries[] | "\(.key)\t\(.value.baseUrl)\t\(.value.models | length)"' \
    "$MODELS_FILE" 2>/dev/null
}

_delete_provider() {
  local name="$1"
  local tmp
  tmp=$(mktemp)
  jq --arg n "$name" 'del(.providers[$n])' "$MODELS_FILE" > "$tmp" && mv "$tmp" "$MODELS_FILE"
}

_merge_provider() {
  local name="$1" payload="$2"
  if [ ! -f "$MODELS_FILE" ]; then
    echo '{"providers":{}}' > "$MODELS_FILE"
  fi
  local tmp
  tmp=$(mktemp)
  jq --arg n "$name" --argjson p "$payload" '.providers[$n] = $p' "$MODELS_FILE" > "$tmp" \
    && mv "$tmp" "$MODELS_FILE"
}

# ── preset picker ────────────────────────────────────────────────────────────

_pick_preset() {
  echo "  Pick a provider type:"
  echo ""
  echo "    1) Ollama               (http://localhost:11434, local)"
  echo "    2) LM Studio            (http://localhost:1234,  local)"
  echo "    3) Custom OpenAI-compatible endpoint"
  echo "    4) Custom Anthropic-compatible endpoint"
  echo "    s) Skip provider setup"
  echo ""
  local choice
  read -r -p "  choice: " choice
  echo "$choice"
}

# ── configure one provider ───────────────────────────────────────────────────

_configure_provider() {
  local preset_base_url="" preset_api="openai" preset_name="" preset_key=""
  local editing_name="${1:-}"
  local cur_base_url="" cur_api="" cur_key=""

  if [ -n "$editing_name" ] && [ -f "$MODELS_FILE" ]; then
    cur_base_url=$(jq -r --arg n "$editing_name" '.providers[$n].baseUrl // ""' "$MODELS_FILE" 2>/dev/null)
    cur_api=$(jq -r --arg n "$editing_name" '.providers[$n].api // "openai"' "$MODELS_FILE" 2>/dev/null)
    cur_key=$(jq -r --arg n "$editing_name" '.providers[$n].apiKey // ""' "$MODELS_FILE" 2>/dev/null)
    preset_base_url="$cur_base_url"
    preset_api="$cur_api"
    preset_name="$editing_name"
    preset_key="$cur_key"
  fi

  if [ -z "$editing_name" ]; then
    local preset
    preset=$(_pick_preset)
    case "$preset" in
      1) preset_base_url="http://localhost:11434" preset_api="openai" preset_name="ollama" ;;
      2) preset_base_url="http://localhost:1234"  preset_api="openai" preset_name="lmstudio" ;;
      3) preset_api="openai" ;;
      4) preset_api="anthropic-messages" ;;
      s|S) return 1 ;;
      *)  echo "  Invalid choice."; return 1 ;;
    esac
  fi

  echo ""

  # Base URL
  local base_url
  if [ -n "$preset_base_url" ]; then
    read -r -p "  Base URL [$preset_base_url]: " base_url
    base_url="${base_url:-$preset_base_url}"
  else
    read -r -p "  Base URL: " base_url
    [ -z "$base_url" ] && { echo "  URL required."; return 1; }
  fi
  base_url="${base_url%/}"

  # API type (only ask for custom presets)
  local api_type="$preset_api"
  if [ -z "$editing_name" ] && [ -z "$preset_name" ]; then
    echo "  API type: $api_type"
  fi

  # API key
  local api_key
  local key_hint
  key_hint=$(_setup_mask "$preset_key")
  read -r -p "  API key [$key_hint]: " api_key
  if [ -z "$api_key" ]; then
    api_key="$preset_key"
  elif [ "$api_key" = "-" ]; then
    api_key=""
  fi

  # Provider name
  local prov_name
  if [ -n "$preset_name" ]; then
    read -r -p "  Provider name [$preset_name]: " prov_name
    prov_name="${prov_name:-$preset_name}"
  else
    local auto_name
    auto_name=$(echo "$base_url" | sed -E 's|https?://||; s|[/:].*||; s/\..*//; s/[^a-zA-Z0-9_-]/_/g')
    [ -z "$auto_name" ] && auto_name="provider"
    read -r -p "  Provider name [$auto_name]: " prov_name
    prov_name="${prov_name:-$auto_name}"
  fi

  echo ""

  # ── Fetch models ─────────────────────────────────────────────────────────
  local model_ids=() model_names=()
  echo "  Fetching models from $base_url..."
  echo ""

  local curl_args=(-s --connect-timeout 5 --max-time 15)
  [ -n "$api_key" ] && curl_args+=(-H "Authorization: Bearer $api_key")

  local raw_response fetched=false

  # Try OpenAI-compatible /v1/models first
  raw_response=$(curl "${curl_args[@]}" "$base_url/v1/models" 2>/dev/null) || true
  if [ -n "$raw_response" ] && echo "$raw_response" | jq -e '.data' &>/dev/null; then
    fetched=true
  fi

  # Ollama fallback: /api/tags
  if [ "$fetched" = false ]; then
    raw_response=$(curl "${curl_args[@]}" "$base_url/api/tags" 2>/dev/null) || true
    if [ -n "$raw_response" ] && echo "$raw_response" | jq -e '.models' &>/dev/null; then
      raw_response=$(echo "$raw_response" | jq '{data: [.models[] | {id: .name, name: .name}]}')
      fetched=true
    fi
  fi

  if [ "$fetched" = true ]; then
    local count
    count=$(echo "$raw_response" | jq '.data | length')
    echo "  Found $count model(s):"
    echo ""

    local idx=0
    while IFS=$'\t' read -r mid mname; do
      model_ids+=("$mid")
      model_names+=("${mname:-$mid}")
      idx=$((idx + 1))
      printf "    %d) %s\n" "$idx" "$mid"
    done < <(echo "$raw_response" | jq -r '.data[] | [.id, (.name // .id)] | @tsv')

    echo ""
    echo "  Enter model numbers to include (comma-separated), or Enter for all:"
    read -r -p "  models [all]: " selection

    if [ -n "${selection:-}" ]; then
      local selected_ids=() selected_names=()
      IFS=',' read -ra sel_nums <<< "$selection"
      for n in "${sel_nums[@]}"; do
        n=$(echo "$n" | tr -d ' ')
        if [ "$n" -ge 1 ] 2>/dev/null && [ "$n" -le "${#model_ids[@]}" ]; then
          selected_ids+=("${model_ids[$((n - 1))]}")
          selected_names+=("${model_names[$((n - 1))]}")
        fi
      done
      model_ids=("${selected_ids[@]}")
      model_names=("${selected_names[@]}")
    fi
  else
    echo "  Could not auto-discover models from $base_url"
    [ -n "$raw_response" ] && echo "  Response: $(echo "$raw_response" | head -c 200)"
    echo ""
  fi

  # Manual entry fallback
  if [ ${#model_ids[@]} -eq 0 ]; then
    local existing_ids=""
    if [ -n "$editing_name" ] && [ -f "$MODELS_FILE" ]; then
      existing_ids=$(jq -r --arg n "$editing_name" \
        '.providers[$n].models[]?.id' "$MODELS_FILE" 2>/dev/null | paste -sd, -)
    fi

    echo "  Enter model IDs (comma-separated):"
    read -r -p "  models [${existing_ids:-}]: " manual
    manual="${manual:-$existing_ids}"
    if [ -n "${manual:-}" ]; then
      IFS=',' read -ra parts <<< "$manual"
      for p in "${parts[@]}"; do
        p=$(echo "$p" | xargs)
        [ -n "$p" ] && model_ids+=("$p") && model_names+=("$p")
      done
    fi
  fi

  if [ ${#model_ids[@]} -eq 0 ]; then
    echo "  No models selected. You can edit shared/models.json later."
  fi
  echo ""

  # ── Build model JSON array, preserving existing metadata ─────────────────
  local models_json_array="["
  for i in "${!model_ids[@]}"; do
    [ "$i" -gt 0 ] && models_json_array+=","
    local mid="${model_ids[$i]}"
    local mname="${model_names[$i]}"

    local reasoning="false" input='["text"]' ctx=131072
    if [ -f "$MODELS_FILE" ]; then
      local existing
      existing=$(jq -r --arg n "$prov_name" --arg id "$mid" \
        '.providers[$n].models[] | select(.id == $id)' \
        "$MODELS_FILE" 2>/dev/null)
      if [ -n "${existing:-}" ]; then
        reasoning=$(echo "$existing" | jq -r '.reasoning // false')
        input=$(echo "$existing" | jq -c '.input // ["text"]')
        ctx=$(echo "$existing" | jq -r '.contextWindow // 131072')
        local ename
        ename=$(echo "$existing" | jq -r '.name // ""')
        [ -n "$ename" ] && mname="$ename"
      fi
    fi

    models_json_array+=$(jq -n \
      --arg id "$mid" \
      --arg name "$mname" \
      --argjson reasoning "$reasoning" \
      --argjson input "$input" \
      --argjson ctx "$ctx" \
      '{id: $id, name: $name, reasoning: $reasoning, input: $input, contextWindow: $ctx}')
  done
  models_json_array+="]"

  # ── Merge into models.json ──────────────────────────────────────────────
  local payload
  payload=$(jq -n \
    --arg baseUrl "$base_url/" \
    --arg api "$api_type" \
    --arg apiKey "$api_key" \
    --argjson models "$models_json_array" \
    '{baseUrl: $baseUrl, api: $api, apiKey: $apiKey, models: $models}')

  # If editing under a different name, remove the old entry
  if [ -n "$editing_name" ] && [ "$editing_name" != "$prov_name" ]; then
    _delete_provider "$editing_name"
  fi

  _merge_provider "$prov_name" "$payload"

  echo "  ✓ Provider '$prov_name' saved (${#model_ids[@]} models)"
  echo ""
}

# ── Provider management loop ─────────────────────────────────────────────────

echo "[1/2] Providers"
echo ""

provider_changed=false

while true; do
  count=$(_provider_count)

  if [ "$count" -eq 0 ]; then
    echo "  No providers configured yet."
    echo ""
    _configure_provider && provider_changed=true || true
    count=$(_provider_count)
    [ "$count" -eq 0 ] && break
    continue
  fi

  echo "  Existing providers:"
  echo ""
  idx=0 prov_names=()
  while IFS=$'\t' read -r pname purl pcount; do
    idx=$((idx + 1))
    prov_names+=("$pname")
    printf "    %d) %-15s (%s, %s models)\n" "$idx" "$pname" "${purl%/}" "$pcount"
  done < <(_list_providers)
  echo ""
  echo "    a) Add a new provider"
  echo "    e) Edit an existing provider (by number)"
  echo "    d) Delete a provider (by number)"
  echo "    s) Continue to role configuration"
  echo ""
  read -r -p "  choice: " action

  case "$action" in
    a|A)
      _configure_provider && provider_changed=true || true
      ;;
    e|E)
      read -r -p "  Edit which provider? [1-$idx]: " edit_num
      if [ "$edit_num" -ge 1 ] 2>/dev/null && [ "$edit_num" -le "$idx" ]; then
        _configure_provider "${prov_names[$((edit_num - 1))]}" && provider_changed=true || true
      else
        echo "  Invalid selection."
      fi
      ;;
    d|D)
      read -r -p "  Delete which provider? [1-$idx]: " del_num
      if [ "$del_num" -ge 1 ] 2>/dev/null && [ "$del_num" -le "$idx" ]; then
        del_name="${prov_names[$((del_num - 1))]}"
        _delete_provider "$del_name"
        echo "  ✓ Deleted '$del_name'"
        provider_changed=true
      else
        echo "  Invalid selection."
      fi
      ;;
    s|S|"")
      break
      ;;
    *)
      echo "  Invalid choice."
      ;;
  esac
  echo ""
done

echo ""

# ── Step 2: Model roles ──────────────────────────────────────────────────────

echo "[2/2] Model roles"
echo ""
echo "  Assign a default model to each role. These are exported as env vars"
echo "  (sourced by env.sh) and referenced in pi-args files."
echo ""

roles_file="$DOT_PI_DIR/model_roles"
role_names=(AGENTIC_MODEL THINKING_MODEL CODING_MODEL VISION_MODEL FAST_MODEL)

# Gather ALL models from ALL providers in models.json
all_prefixed_ids=()
if [ -f "$MODELS_FILE" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && all_prefixed_ids+=("$line")
  done < <(jq -r '.providers | to_entries[] | .key as $p | .value.models[]? | "\($p)/\(.id)"' "$MODELS_FILE" 2>/dev/null)
fi

if [ ${#all_prefixed_ids[@]} -eq 0 ]; then
  echo "  No models in models.json — skipping role assignment."
  echo "  Re-run 'dotpi setup' after adding a provider."
  echo ""
else
  role_vals=()
  for role in "${role_names[@]}"; do
    cur=$(_setup_read_env_var "$roles_file" "$role")
    role_vals+=("$(_setup_select_model "$role" "$cur" "${all_prefixed_ids[@]}")")
    echo ""
  done

  {
    for ri in "${!role_names[@]}"; do
      echo "export ${role_names[$ri]}=${role_vals[$ri]}"
    done
  } > "$roles_file"
  echo "  ✓ Wrote $roles_file"
  echo ""
fi

# ── Summary ──────────────────────────────────────────────────────────────────

echo "Summary"
echo "-------"
echo ""

if [ -f "$MODELS_FILE" ]; then
  while IFS=$'\t' read -r pname purl pcount; do
    printf "  %-15s %s (%s models)\n" "$pname" "${purl%/}" "$pcount"
  done < <(_list_providers)
else
  echo "  No providers configured."
fi
echo ""

if [ -f "$roles_file" ]; then
  for role in "${role_names[@]}"; do
    v=$(_setup_read_env_var "$roles_file" "$role")
    echo "  ${role}: ${v:-(not set)}"
  done
fi
echo ""

echo "  Local config (gitignored, safe to edit by hand):"
echo "    $MODELS_FILE    (providers, API keys, model lists)"
echo "    $roles_file              (role → model env vars; sourced by env.sh)"
echo ""

if [ -z "${DOT_PI_INSTALLED:-}" ]; then
  echo "  Next steps:"
  echo "    1. Add to your shell profile:"
  echo "       export PATH=\"\$HOME/.dot-pi/bin:\$PATH\""
  echo "       source \"\$HOME/.dot-pi/env.sh\""
  echo "    2. Start a session:  lm"
else
  echo "  Re-run 'dotpi setup' anytime to add, edit, or remove providers."
  echo "  Start a session:  lm"
fi
echo ""
