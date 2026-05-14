# pi argument loading from agents/<name>/pi-args (env expansion only).

_load_pi_args() {
  local config_dir="$1" _line
  _pi_args=()
  if [ -f "$config_dir/pi-args" ]; then
    while IFS= read -r _line || [ -n "$_line" ]; do
      [[ -z "$_line" || "$_line" == \#* ]] && continue
      _line="$(_expand_env_vars "$_line")"
      # shellcheck disable=SC2206  # intentional word-splitting so multi-word flags expand
      _pi_args+=($_line)
    done < "$config_dir/pi-args"
  fi
}
