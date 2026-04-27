# Shared helpers for dotpi subcommands.
# Sourced by the dotpi dispatcher — do not execute directly.

# shellcheck disable=SC2034
SHARED_DIR="$DOT_PI_DIR/shared"

resolve_dir() {
  local name="$1"
  if [ -d "$DOT_PI_DIR/agents/$name" ]; then
    echo "$DOT_PI_DIR/agents/$name"
  else
    return 1
  fi
}
