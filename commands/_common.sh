# Shared helpers for dotpi subcommands.
# Sourced by the dotpi dispatcher — do not execute directly.

# shellcheck disable=SC2034
SHARED_DIR="$DOT_PI_DIR/shared"

link_extension_bundle() {
  local bundle_dir="$1" target_dir="$2" rel_prefix="$3" ext name
  [ -d "$bundle_dir" ] || return 0
  mkdir -p "$target_dir"
  for ext in "$bundle_dir"/*; do
    [ -e "$ext" ] || [ -L "$ext" ] || continue
    name=$(basename "$ext")
    if [ -e "$target_dir/$name" ] && [ ! -L "$target_dir/$name" ]; then
      echo "sync: keeping existing non-symlink extension $target_dir/$name" >&2
      continue
    fi
    [ -L "$target_dir/$name" ] && rm "$target_dir/$name"
    ln -s "$rel_prefix/$name" "$target_dir/$name"
  done
}

resolve_dir() {
  local name="$1"
  if [ -d "$DOT_PI_DIR/agents/$name" ]; then
    echo "$DOT_PI_DIR/agents/$name"
  else
    return 1
  fi
}
