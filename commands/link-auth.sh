# dotpi link-auth — symlink auth.json from one agent config (or path) into another
# Sourced by the dotpi dispatcher — do not execute directly.

[ $# -lt 2 ] && { echo "Error: source and destination required"; exit 1; }

src="$1"
dst="$2"

if [ "$src" = "shared" ]; then
  src_path="$DOT_PI_DIR/shared/auth.json"
  if [ ! -f "$src_path" ]; then
    echo "Error: shared/auth.json missing — run dotpi sync"
    exit 1
  fi
elif [ -f "$src" ]; then
  src_path="$(cd "$(dirname "$src")" && pwd)/$(basename "$src")"
elif [ -f "$DOT_PI_DIR/agents/$src/auth.json" ]; then
  src_path="$DOT_PI_DIR/agents/$src/auth.json"
else
  echo "Error: cannot find auth.json at '$src' or in agent '$src' (use 'shared' for shared/auth.json)"
  exit 1
fi

dst_dir=$(resolve_dir "$dst") || {
  echo "Error: '$dst' does not exist as an agent"
  exit 1
}

ln -sf "$src_path" "$dst_dir/auth.json"
echo "Linked $dst_dir/auth.json -> $src_path"
