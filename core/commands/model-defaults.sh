# dotpi model-defaults — configure local fallback model aliases.
# Sourced by the dotpi dispatcher — do not execute directly.

command -v jq &>/dev/null || {
  echo "Error: 'jq' is required. Install it first."
  exit 1
}

defaults_file="$(resolve_model_defaults_file)"
write_model_defaults_file "$defaults_file"

models_file="$(resolve_models_file)"
all_models=()
if [ -f "$models_file" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && all_models+=("$line")
  done < <(list_available_model_ids "$models_file")
fi

echo ""
echo "dotpi model-defaults"
echo "===================="
echo ""
echo "Configure local fallback model aliases used by pi-args files."
echo "Leave a value empty to let pi use its settings.json default."
echo ""

if [ ${#all_models[@]} -eq 0 ]; then
  echo "No models found in $models_file"
  echo "Run 'dotpi setup' first to configure providers/models."
  echo ""
  return 0 2>/dev/null || exit 0
fi

role_names=(DEFAULT_AGENTIC_MODEL DEFAULT_FAST_MODEL DEFAULT_VLM_MODEL)
role_vals=()
for role in "${role_names[@]}"; do
  cur="$(read_export_var "$defaults_file" "$role")"
  role_vals+=("$(select_model_id "$role" "$cur" "${all_models[@]}")")
  echo ""
done

{
  echo "# Local fallback model aliases used by pi-args files."
  echo "# Leave a value empty to let pi fall back to its settings.json default."
  for i in "${!role_names[@]}"; do
    echo "export ${role_names[$i]}=\"\${${role_names[$i]}:-${role_vals[$i]}}\""
  done
} > "$defaults_file"

echo "Wrote $defaults_file"
echo ""
