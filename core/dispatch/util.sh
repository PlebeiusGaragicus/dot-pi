# General helpers used by dispatch modules.

_expand_env_vars() {
  local s="$1" out="" var name
  while [[ "$s" =~ \$\{?([A-Za-z_][A-Za-z0-9_]*)\}? ]]; do
    name="${BASH_REMATCH[1]}"
    var="${BASH_REMATCH[0]}"
    out+="${s%%"$var"*}${!name-}"
    s="${s#*"$var"}"
  done
  printf '%s' "$out$s"
}

_slugify_workspace_name() {
  local name="$*"
  name=$(printf '%s' "$name" | tr '[:upper:]' '[:lower:]')
  name=$(printf '%s' "$name" | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')
  [ -n "$name" ] && printf '%s' "$name" || printf 'workspace'
}

_trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

_bootstrap_file() {
  local config_dir="$1"
  [ -f "$config_dir/bootstrap.sh" ] && printf '%s\n' "$config_dir/bootstrap.sh"
  return 0
}

