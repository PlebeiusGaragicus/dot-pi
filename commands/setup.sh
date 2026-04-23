# dotpi setup — interactive setup wizard (API keys, models, roles)
# Sourced by the dotpi dispatcher — do not execute directly.

_init_check_deps() {
  local missing=()
  command -v jq &>/dev/null || missing+=(jq)
  command -v curl &>/dev/null || missing+=(curl)
  if [ ${#missing[@]} -gt 0 ]; then
    echo "Error: missing required tools: ${missing[*]}"
    echo "  brew install ${missing[*]}  (macOS)"
    echo "  apt install ${missing[*]}   (Debian/Ubuntu)"
    exit 1
  fi
}

_init_mask() {
  local val="$1"
  if [ -z "$val" ]; then
    echo "(empty)"
  elif [ ${#val} -le 8 ]; then
    echo "****"
  else
    echo "${val:0:4}****${val: -2}"
  fi
}

_init_read_env_var() {
  local file="$1" varname="$2"
  if [ -f "$file" ]; then
    grep "^export ${varname}=" "$file" 2>/dev/null | head -1 | sed "s/^export ${varname}=//"
  fi
}

_init_prompt_key() {
  local varname="$1" current="$2" label="$3"
  local masked
  masked=$(_init_mask "$current")
  local input
  read -r -p "  ${label:-$varname} [$masked]: " input
  if [ -z "$input" ]; then
    echo "$current"
  elif [ "$input" = "-" ]; then
    echo ""
  else
    echo "$input"
  fi
}

_init_select_model() {
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

_init_check_deps

echo ""
echo "dot-pi setup"
echo "============"
echo ""
echo "Re-run anytime. Press Enter to keep current values, type to replace, - to clear."
echo ""

# ── Step 1: Provider endpoint ──────────────────────────────────────────────
echo "[1/5] Provider endpoint"
echo ""

cur_base_url="" cur_api_type="" cur_api_key_var=""
if [ -f "$SHARED_DIR/models.json" ]; then
  cur_base_url=$(jq -r '.providers | to_entries[0].value.baseUrl // ""' "$SHARED_DIR/models.json" 2>/dev/null)
  cur_api_type=$(jq -r '.providers | to_entries[0].value.api // ""' "$SHARED_DIR/models.json" 2>/dev/null)
  cur_api_key_var=$(jq -r '.providers | to_entries[0].value.apiKey // ""' "$SHARED_DIR/models.json" 2>/dev/null)
fi
cur_base_url="${cur_base_url%/}"
cur_api_type="${cur_api_type:-openai}"
cur_api_key_var="${cur_api_key_var:-PLEBCHAT_API_KEY}"

base_url="$cur_base_url" api_type="$cur_api_type"

if [ -n "$cur_base_url" ]; then
  echo "  Current: $cur_base_url ($cur_api_type)"
  read -r -p "  Change endpoint? [y/N]: " edit_endpoint
  if [[ "${edit_endpoint:-}" =~ ^[Yy] ]]; then
    read -r -p "  Base URL [$cur_base_url]: " base_url
    base_url="${base_url:-$cur_base_url}"
    base_url="${base_url%/}"

    echo "  API compatibility:"
    echo "    1) openai"
    echo "    2) anthropic-messages"
    default_n=1
    [ "$cur_api_type" = "anthropic-messages" ] && default_n=2
    read -r -p "  choice [$default_n]: " api_choice
    api_choice="${api_choice:-$default_n}"
    [ "$api_choice" = "2" ] && api_type="anthropic-messages" || api_type="openai"
  fi
else
  read -r -p "  Base URL [https://localhost:1234]: " base_url
  base_url="${base_url:-https://localhost:1234}"
  base_url="${base_url%/}"

  echo "  API compatibility:"
  echo "    1) openai"
  echo "    2) anthropic-messages"
  read -r -p "  choice [1]: " api_choice
  api_choice="${api_choice:-1}"
  [ "$api_choice" = "2" ] && api_type="anthropic-messages" || api_type="openai"
fi

echo ""

# ── Step 2: API keys ──────────────────────────────────────────────────────
echo "[2/5] API keys (.env)"
echo ""

env_file="$DOT_PI_DIR/.env"
example_file="$DOT_PI_DIR/.env.example"

key_names=()
if [ -f "$example_file" ]; then
  while IFS= read -r line || [ -n "$line" ]; do
    [[ "$line" =~ ^export\ ([A-Za-z_][A-Za-z0-9_]*)= ]] && key_names+=("${BASH_REMATCH[1]}")
  done < "$example_file"
fi
[ ${#key_names[@]} -eq 0 ] && key_names=(PLEBCHAT_API_KEY TAVILY_API_KEY XAI_API_KEY)

env_vals=()
for ki in "${!key_names[@]}"; do
  kn="${key_names[$ki]}"
  cur=$(_init_read_env_var "$env_file" "$kn")
  env_vals+=("$(_init_prompt_key "$kn" "$cur" "$kn")")
done

provider_api_key_var="$cur_api_key_var"
provider_api_key=""
for ki in "${!key_names[@]}"; do
  if [ "${key_names[$ki]}" = "$provider_api_key_var" ]; then
    provider_api_key="${env_vals[$ki]}"
    break
  fi
done

{
  for ki in "${!key_names[@]}"; do
    echo "export ${key_names[$ki]}=${env_vals[$ki]}"
  done
} > "$env_file"
echo ""
echo "  Wrote $env_file"
echo ""

# ── Step 3: Fetch models ───────────────────────────────────────────────────
echo "[3/5] Fetch models from $base_url"
echo ""

curl_args=(-s --connect-timeout 10 --max-time 20)
if [ -n "$provider_api_key" ]; then
  curl_args+=(-H "Authorization: Bearer $provider_api_key")
fi

model_ids=() model_names=()
raw_response=$(curl "${curl_args[@]}" "$base_url/v1/models" 2>/dev/null) || true

if [ -n "$raw_response" ] && echo "$raw_response" | jq -e '.data' &>/dev/null; then
  count=$(echo "$raw_response" | jq '.data | length')
  echo "  Found $count model(s):"
  echo ""

  idx=0
  while IFS=$'\t' read -r mid mname; do
    model_ids+=("$mid")
    model_names+=("${mname:-$mid}")
    idx=$((idx + 1))
    printf "    %d) %s  (%s)\n" "$idx" "$mid" "${mname:-$mid}"
  done < <(echo "$raw_response" | jq -r '.data[] | [.id, (.name // .id)] | @tsv')

  echo ""
  echo "  Enter model numbers to include (comma-separated), or Enter for all:"
  read -r -p "  models [all]: " selection

  if [ -n "${selection:-}" ]; then
    selected_ids=() selected_names=()
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
  echo "  Could not fetch models from $base_url/v1/models"
  if [ -n "$raw_response" ]; then
    echo "  Response: $(echo "$raw_response" | head -c 200)"
  fi
  echo ""
  echo "  Enter model IDs manually (comma-separated):"

  existing_ids=""
  if [ -f "$SHARED_DIR/models.json" ]; then
    existing_ids=$(jq -r '.providers | to_entries[0].value.models[]?.id' "$SHARED_DIR/models.json" 2>/dev/null | paste -sd, -)
  fi

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
  echo "  No models configured. You can edit shared/models.json manually later."
  echo ""
fi

provider_name=$(echo "$base_url" | sed -E 's|https?://||; s|[/:].*||; s/\..*//; s/[^a-zA-Z0-9_-]/_/g')
[ -z "$provider_name" ] && provider_name="provider"

models_json_array="["
for i in "${!model_ids[@]}"; do
  [ "$i" -gt 0 ] && models_json_array+=","
  mid="${model_ids[$i]}"
  mname="${model_names[$i]}"

  reasoning="false" input='["text"]' ctx=131072
  if [ -f "$SHARED_DIR/models.json" ]; then
    existing=$(jq -r --arg id "$mid" \
      '.providers | to_entries[0].value.models[] | select(.id == $id)' \
      "$SHARED_DIR/models.json" 2>/dev/null)
    if [ -n "${existing:-}" ]; then
      reasoning=$(echo "$existing" | jq -r '.reasoning // false')
      input=$(echo "$existing" | jq -c '.input // ["text"]')
      ctx=$(echo "$existing" | jq -r '.contextWindow // 131072')
      mname=$(echo "$existing" | jq -r '.name // ""')
      [ -z "$mname" ] && mname="${model_names[$i]}"
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

mkdir -p "$SHARED_DIR"
jq -n \
  --arg pname "$provider_name" \
  --arg baseUrl "$base_url/" \
  --arg api "$api_type" \
  --arg apiKey "$provider_api_key_var" \
  --argjson models "$models_json_array" \
  '{providers: {($pname): {baseUrl: $baseUrl, api: $api, apiKey: $apiKey, models: $models}}}' \
  > "$SHARED_DIR/models.json"

echo ""
echo "  Wrote $SHARED_DIR/models.json (${#model_ids[@]} models)"
echo ""

# ── Step 4: Model roles ───────────────────────────────────────────────────
echo "[4/5] Model roles (model_roles)"
echo ""

roles_file="$DOT_PI_DIR/model_roles"
role_names=(AGENTIC_MODEL THINKING_MODEL CODING_MODEL VISION_MODEL FAST_MODEL)

prefixed_ids=()
for mid in "${model_ids[@]}"; do
  prefixed_ids+=("${provider_name}/${mid}")
done

role_vals=()
for role in "${role_names[@]}"; do
  cur=$(_init_read_env_var "$roles_file" "$role")
  role_vals+=("$(_init_select_model "$role" "$cur" "${prefixed_ids[@]}")")
  echo ""
done

{
  for ri in "${!role_names[@]}"; do
    echo "export ${role_names[$ri]}=${role_vals[$ri]}"
  done
} > "$roles_file"
echo "  Wrote $roles_file"
echo ""

# ── Step 5: Verify ────────────────────────────────────────────────────────
echo "[5/5] Summary"
echo ""

echo "  Provider:  $base_url ($api_type)"
echo "  Models:    ${#model_ids[@]} configured"
for ki in "${!key_names[@]}"; do
  echo "  ${key_names[$ki]}: $(_init_mask "${env_vals[$ki]}")"
done
for ri in "${!role_names[@]}"; do
  v="${role_vals[$ri]}"
  echo "  ${role_names[$ri]}: ${v:-(not set)}"
done

warnings=0
[ -z "${env_vals[0]:-}" ] && echo "" && echo "  Warning: ${key_names[0]} is empty" && warnings=1
[ ${#model_ids[@]} -eq 0 ] && echo "  Warning: no models configured" && warnings=1

echo ""
if [ "$warnings" -eq 0 ]; then
  echo "  Setup complete!"
else
  echo "  Setup complete (with warnings -- re-run to fix)."
fi
echo ""
if [ -z "${DOT_PI_INSTALLED:-}" ]; then
  echo "  Next steps:"
  echo "    1. Add to your shell profile:  source $DOT_PI_DIR/bash_aliases"
  echo "    2. Start a session:            p talk"
else
  echo "  Start a session:  p talk"
fi
echo ""
