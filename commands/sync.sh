#!/usr/bin/env bash
# dotpi sync — rebuild bin/ symlinks from agents/ and teams/ directories.
# Called automatically after dotpi create / create-agent and by the installer.

BIN_DIR="$DOT_PI_DIR/bin"
mkdir -p "$BIN_DIR"

added=0 removed=0

# Create symlinks for every agent and team
for search_dir in "$DOT_PI_DIR/teams" "$DOT_PI_DIR/agents"; do
  [ -d "$search_dir" ] || continue
  for d in "$search_dir"/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    link="$BIN_DIR/$name"
    if [ ! -L "$link" ]; then
      ln -sf ../dispatch-agent "$link"
      added=$((added + 1))
    fi
  done
done

# Always ensure these special entries exist
if [ ! -L "$BIN_DIR/run-retro" ]; then
  ln -sf ../dispatch-agent "$BIN_DIR/run-retro"
  added=$((added + 1))
fi
if [ ! -L "$BIN_DIR/dotpi" ]; then
  ln -sf ../dotpi "$BIN_DIR/dotpi"
  added=$((added + 1))
fi

# Remove stale symlinks (point to dispatch-agent/dotpi but the agent/team no longer exists)
for link in "$BIN_DIR"/*; do
  [ -L "$link" ] || continue
  name=$(basename "$link")
  # Skip special entries
  [ "$name" = "dotpi" ] && continue
  [ "$name" = "run-retro" ] && continue

  target=$(readlink "$link" 2>/dev/null || true)
  case "$target" in
    ../dispatch-agent|*/dispatch-agent)
      if [ ! -d "$DOT_PI_DIR/teams/$name" ] && [ ! -d "$DOT_PI_DIR/agents/$name" ]; then
        rm "$link"
        removed=$((removed + 1))
      fi
      ;;
  esac
done

echo "sync: $added added, $removed removed ($(ls "$BIN_DIR" | wc -l | tr -d ' ') total in bin/)"
