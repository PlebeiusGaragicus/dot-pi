#!/usr/bin/env bash
# dotpi sync — rebuild bin/ symlinks from agents/ directories.
# Called automatically after dotpi create / create-agent and by the installer.

BIN_DIR="$DOT_PI_DIR/bin"
mkdir -p "$BIN_DIR"

# Bootstrap shared/settings.json from example if missing (gitignored, local-only)
if [ ! -f "$DOT_PI_DIR/shared/settings.json" ] && \
   [ -f "$DOT_PI_DIR/bootstrap/settings.json.example" ]; then
  cp "$DOT_PI_DIR/bootstrap/settings.json.example" "$DOT_PI_DIR/shared/settings.json"
  echo "sync: created shared/settings.json from bootstrap/settings.json.example"
fi

# Bootstrap model-defaults from example if missing (gitignored, local-only)
if [ ! -f "$DOT_PI_DIR/model-defaults" ] && \
   [ -f "$DOT_PI_DIR/bootstrap/model-defaults.example" ]; then
  cp "$DOT_PI_DIR/bootstrap/model-defaults.example" "$DOT_PI_DIR/model-defaults"
  echo "sync: created model-defaults from bootstrap/model-defaults.example"
fi

# Symlink shared/models.json to system pi config if missing
_dotpi_models="$DOT_PI_DIR/shared/models.json"
_pi_system_models="$HOME/.pi/agent/models.json"
if [ ! -e "$_dotpi_models" ] && [ ! -L "$_dotpi_models" ]; then
  if [ -f "$_pi_system_models" ]; then
    ln -sf "$_pi_system_models" "$_dotpi_models"
    echo "sync: symlinked shared/models.json -> $_pi_system_models"
  else
    echo "sync: shared/models.json missing and ~/.pi/agent/models.json not found — run 'dotpi setup' or 'pi' first"
  fi
fi

added=0 removed=0

# Wire default extensions into reusable subagent configs at their canonical roots.
for subagent in "$DOT_PI_DIR"/subagents/*/; do
  [ -d "$subagent" ] || continue
  [ -f "$subagent/SYSTEM.md" ] || [ -f "$subagent/APPEND_SYSTEM.md" ] || continue
  link_extension_bundle "$SHARED_DIR/extensions-subagents" "$subagent/extensions" "../../../shared/extensions-subagents"
done

# Create symlinks for every agent config
for d in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  link_extension_bundle "$SHARED_DIR/extensions-common" "$d/extensions" "../../../shared/extensions-common"
  if [ -e "$d/extensions/agent-orchestrator/index.ts" ]; then
    for subagent in "$d"/agents/*/; do
      [ -d "$subagent" ] || continue
      if [ -L "${subagent%/}" ]; then
        target=$(readlink "${subagent%/}" 2>/dev/null || true)
        case "$target" in
          ../../../subagents/*|"$DOT_PI_DIR"/subagents/*) ;;
          *)
            echo "sync: invalid subagent symlink ${subagent%/} -> $target" >&2
            echo "sync: reusable subagents must live under $DOT_PI_DIR/subagents and be linked into MAS agents/ directories" >&2
            exit 1
            ;;
        esac
        continue
      fi
      [ -f "$subagent/SYSTEM.md" ] || [ -f "$subagent/APPEND_SYSTEM.md" ] || continue
      link_extension_bundle "$SHARED_DIR/extensions-subagents" "$subagent/extensions" "../../../../../shared/extensions-subagents"
    done
  fi
  link="$BIN_DIR/$name"
  if [ ! -L "$link" ]; then
    ln -sf ../dispatch-agent "$link"
    added=$((added + 1))
  fi
done

# Always ensure these special entries exist
if [ ! -L "$BIN_DIR/resume" ]; then
  ln -sf ../dispatch-agent "$BIN_DIR/resume"
  added=$((added + 1))
fi
if [ ! -L "$BIN_DIR/dotpi" ]; then
  ln -sf ../dotpi "$BIN_DIR/dotpi"
  added=$((added + 1))
fi

# Remove stale symlinks (point to dispatch-agent/dotpi but the agent no longer exists)
for link in "$BIN_DIR"/*; do
  [ -L "$link" ] || continue
  name=$(basename "$link")
  # Skip special entries
  [ "$name" = "dotpi" ] && continue
  [ "$name" = "resume" ] && continue

  target=$(readlink "$link" 2>/dev/null || true)
  case "$target" in
    ../dispatch-agent|*/dispatch-agent)
      if [ ! -d "$DOT_PI_DIR/agents/$name" ]; then
        rm "$link"
        removed=$((removed + 1))
      fi
      ;;
  esac
done

echo "sync: $added added, $removed removed ($(ls "$BIN_DIR" | wc -l | tr -d ' ') total in bin/)"
