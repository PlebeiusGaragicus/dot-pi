# dotpi link-skill — symlink one or more shared skills into a team or agent
# Sourced by the dotpi dispatcher — do not execute directly.

[ $# -lt 2 ] && { echo "Error: team/agent name and at least one skill required"; exit 1; }

target="$1"
shift

dst_dir=$(resolve_dir "$target") || {
  echo "Error: '$target' does not exist as a team or agent"
  exit 1
}

mkdir -p "$dst_dir/skills"

for name in "$@"; do
  src="$SHARED_DIR/skills/$name"
  if [ ! -d "$src" ]; then
    echo "Error: no shared skill at $src"
    exit 1
  fi
  ln -sf "../../../shared/skills/$name" "$dst_dir/skills/$name"
  echo "Linked $dst_dir/skills/$name -> ../../../shared/skills/$name"
done
