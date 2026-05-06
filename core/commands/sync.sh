#!/usr/bin/env bash
# dotpi sync — rebuild bin/ symlinks, ensure shared/ symlinks to ~/.pi/agent/, and wire
# auth.json, models.json, settings.json, bin/, and extensions into every agent and
# subagent config directory. Called after dotpi create / create-agent and by the installer.

BIN_DIR="$DOT_PI_DIR/core/bin"
mkdir -p "$BIN_DIR"

# Symlink shared/settings.json to system pi config if missing
_dotpi_settings="$DOT_PI_DIR/shared/settings.json"
_pi_system_settings="$HOME/.pi/agent/settings.json"
if [ ! -e "$_dotpi_settings" ] && [ ! -L "$_dotpi_settings" ]; then
  if [ -f "$_pi_system_settings" ]; then
    ln -sf "$_pi_system_settings" "$_dotpi_settings"
    echo "sync: symlinked shared/settings.json -> $_pi_system_settings"
  else
    echo "sync: shared/settings.json missing and ~/.pi/agent/settings.json not found — run 'pi' first"
  fi
fi

# Create model-defaults with empty defaults if missing (gitignored, local-only)
if [ ! -f "$DOT_PI_DIR/model-defaults" ]; then
  cat > "$DOT_PI_DIR/model-defaults" <<'DEFAULTS'
# Local fallback model aliases used by pi-args files.
# Leave a value empty to let pi fall back to its settings.json default.
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
DEFAULTS
  echo "sync: created model-defaults with empty defaults"
fi

# Symlink shared/auth.json to system pi config if missing
_dotpi_auth="$DOT_PI_DIR/shared/auth.json"
_pi_system_auth="$HOME/.pi/agent/auth.json"
if [ ! -e "$_dotpi_auth" ] && [ ! -L "$_dotpi_auth" ]; then
  if [ -f "$_pi_system_auth" ]; then
    ln -sf "$_pi_system_auth" "$_dotpi_auth"
    echo "sync: symlinked shared/auth.json -> $_pi_system_auth"
  else
    echo "sync: shared/auth.json missing and ~/.pi/agent/auth.json not found — run 'pi' first"
  fi
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

# Wire default extensions and auth into reusable subagent configs at their canonical roots.
for subagent in "$DOT_PI_DIR"/subagents/*/; do
  [ -d "$subagent" ] || continue
  [ -f "$subagent/SYSTEM.md" ] || [ -f "$subagent/APPEND_SYSTEM.md" ] || continue
  ln -sf ../../shared/auth.json "$subagent/auth.json"
  ln -sf ../../shared/models.json "$subagent/models.json"
  ln -sf ../../shared/settings.json "$subagent/settings.json"
  [ -L "$subagent/bin" ] || ln -sf ../../shared/bin "$subagent/bin"
  link_extension_bundle "$SHARED_DIR/extensions-subagents" "$subagent/extensions" "../../../shared/extensions-subagents"
done

# Create symlinks for every agent config
for d in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$d" ] || continue
  name=$(basename "$d")
  mkdir -p "$d/prompts"
  ln -sfn ../../../shared/prompts/introduction.md "$d/prompts/introduction.md"
  # Legacy prompts/help.md (removed); drop stale symlinks or old copies
  if [ -L "$d/prompts/help.md" ] || [ -f "$d/prompts/help.md" ]; then
    rm -f "$d/prompts/help.md"
  fi
  ln -sf ../../shared/auth.json "$d/auth.json"
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
      ln -sf ../../../../shared/auth.json "$subagent/auth.json"
      ln -sf ../../../../shared/models.json "$subagent/models.json"
      ln -sf ../../../../shared/settings.json "$subagent/settings.json"
      [ -L "$subagent/bin" ] || ln -sf ../../../../shared/bin "$subagent/bin"
      link_extension_bundle "$SHARED_DIR/extensions-subagents" "$subagent/extensions" "../../../../../shared/extensions-subagents"
    done
  fi
  link="$BIN_DIR/$name"
  if [ ! -L "$link" ]; then
    ln -sf ../../dispatch-agent "$link"
    added=$((added + 1))
  fi
done

# Always ensure these special entries exist
if [ ! -L "$BIN_DIR/resume" ]; then
  ln -sf ../../dispatch-agent "$BIN_DIR/resume"
  added=$((added + 1))
fi
if [ ! -L "$BIN_DIR/dotpi" ]; then
  ln -sf ../../dotpi "$BIN_DIR/dotpi"
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
    ../../dispatch-agent|*/dispatch-agent)
      if [ ! -d "$DOT_PI_DIR/agents/$name" ]; then
        rm "$link"
        removed=$((removed + 1))
      fi
      ;;
  esac
done

echo "sync: $added added, $removed removed ($(ls "$BIN_DIR" | wc -l | tr -d ' ') total in core/bin/)"
