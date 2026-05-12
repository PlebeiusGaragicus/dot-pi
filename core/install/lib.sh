#!/usr/bin/env bash
# Shared install/relink helpers for dot-pi's Pi package lifecycle.

dotpi_overlay_dir() {
  printf '%s\n' "${DOT_PI_OVERLAY:-$HOME/.pi/dot-pi}"
}

dotpi_create_file_if_missing() {
  local path="$1" mode="${2:-}"
  shift 2 || true
  [ -e "$path" ] && return 0
  mkdir -p "$(dirname "$path")"
  {
    umask 077
    : > "$path"
  }
  if [ $# -gt 0 ]; then
    printf '%s\n' "$@" > "$path"
  fi
  [ -n "$mode" ] && chmod "$mode" "$path" 2>/dev/null || true
}

dotpi_seed_settings_if_missing() {
  local path="$1"
  if [ -e "$path" ] && [ ! -f "$path" ]; then
    return 0
  fi
  mkdir -p "$(dirname "$path")"
  if [ ! -f "$path" ]; then
    {
      umask 077
      cat > "$path" <<'EOF'
{
  "enableInstallTelemetry": false,
  "theme": "synthwave",
  "collapseChangelog": true
}
EOF
    }
    return 0
  fi
  command -v node >/dev/null 2>&1 || return 0
  node - "$path" <<'NODE'
const fs = require("node:fs");
const path = process.argv[2];
const defaults = {
  enableInstallTelemetry: false,
  theme: "synthwave",
  collapseChangelog: true,
};

let data;
try {
  data = JSON.parse(fs.readFileSync(path, "utf8"));
} catch {
  process.exit(0);
}

if (!data || Array.isArray(data) || typeof data !== "object") process.exit(0);

let changed = false;
for (const [key, value] of Object.entries(defaults)) {
  if (!(key in data)) {
    data[key] = value;
    changed = true;
  }
}

if (!changed) process.exit(0);

const tmp = `${path}.tmp-${process.pid}`;
fs.writeFileSync(tmp, `${JSON.stringify(data, null, 2)}\n`, { mode: 0o600 });
fs.renameSync(tmp, path);
NODE
}

dotpi_link_force_symlink() {
  local target="$1" link="$2"
  if [ -e "$link" ] && [ ! -L "$link" ]; then
    printf 'postinstall: keeping existing non-symlink %s\n' "$link" >&2
    return 0
  fi
  ln -sfn "$target" "$link"
}

dotpi_link_if_absent() {
  local target="$1" link="$2"
  if [ -e "$link" ] || [ -L "$link" ]; then
    return 0
  fi
  ln -s "$target" "$link"
}

dotpi_link_extension_bundle() {
  local bundle_dir="$1" target_dir="$2" rel_prefix="$3" ext name
  [ -d "$bundle_dir" ] || return 0
  mkdir -p "$target_dir"
  for ext in "$bundle_dir"/*; do
    [ -e "$ext" ] || [ -L "$ext" ] || continue
    name=$(basename "$ext")
    if [ -e "$target_dir/$name" ] && [ ! -L "$target_dir/$name" ]; then
      printf 'postinstall: keeping existing non-symlink extension %s\n' "$target_dir/$name" >&2
      continue
    fi
    [ -L "$target_dir/$name" ] && rm "$target_dir/$name"
    ln -s "$rel_prefix/$name" "$target_dir/$name"
  done
}

dotpi_link_extension_helpers() {
  local target_dir="$1" rel_prefix="$2"
  [ -d "$DOT_PI_DIR/shared/extensions/lib" ] || return 0
  mkdir -p "$target_dir"
  dotpi_link_force_symlink "$rel_prefix/lib" "$target_dir/lib"
}

dotpi_ensure_overlay_skeleton() {
  local overlay="$1" agent="$2" agent_overlay
  mkdir -p "$overlay"
  dotpi_seed_settings_if_missing "$overlay/settings.json"
  agent_overlay="$overlay/$agent"
  mkdir -p \
    "$agent_overlay/sessions" \
    "$agent_overlay/prompts" \
    "$agent_overlay/skills" \
    "$agent_overlay/extensions" \
    "$agent_overlay/themes"
  dotpi_link_force_symlink "$HOME/.pi/agent/bin" "$agent_overlay/bin"
}

dotpi_link_overlay_entries() {
  local overlay="$1" agent_dir="$2" agent="$3" kind entry name rel
  for kind in prompts skills extensions themes; do
    mkdir -p "$agent_dir/$kind"
    [ -d "$overlay/$agent/$kind" ] || continue
    for entry in "$overlay/$agent/$kind"/*; do
      [ -e "$entry" ] || [ -L "$entry" ] || continue
      name=$(basename "$entry")
      rel="../../../$(basename "$overlay")/$agent/$kind/$name"
      # Relative links only work for the default overlay beside ~/.pi/agent.
      # Use absolute links for custom DOT_PI_OVERLAY values and for clarity.
      rel="$entry"
      dotpi_link_if_absent "$rel" "$agent_dir/$kind/$name"
    done
  done
}

dotpi_relink() {
  local dot_pi_dir="$1" overlay="${2:-$(dotpi_overlay_dir)}"
  local bin_dir="$dot_pi_dir/core/bin" shared_dir="$dot_pi_dir/shared"
  local pi_agent_dir="${PI_CODING_AGENT_DIR:-$HOME/.pi/agent}"
  local d name link

  mkdir -p "$bin_dir" "$shared_dir" "$HOME/.pi/agent/bin"

  dotpi_seed_settings_if_missing "$overlay/settings.json"
  dotpi_link_force_symlink "$HOME/.pi/agent/auth.json" "$overlay/auth.json"
  dotpi_link_force_symlink "$HOME/.pi/agent/models.json" "$overlay/models.json"
  dotpi_link_force_symlink "$overlay/settings.json" "$shared_dir/settings.json"
  dotpi_link_force_symlink "$overlay/auth.json" "$shared_dir/auth.json"
  dotpi_link_force_symlink "$overlay/models.json" "$shared_dir/models.json"

  for d in "$dot_pi_dir"/agents/*/; do
    [ -d "$d" ] || continue
    name=$(basename "$d")
    dotpi_ensure_overlay_skeleton "$overlay" "$name"

    mkdir -p "$d/prompts" "$d/skills" "$d/extensions" "$d/themes"
    dotpi_link_force_symlink "../../../shared/prompts/introduction.md" "$d/prompts/introduction.md"
    [ -L "$d/prompts/help.md" ] && rm -f "$d/prompts/help.md"
    dotpi_link_force_symlink "../../shared/auth.json" "$d/auth.json"
    dotpi_link_force_symlink "../../shared/models.json" "$d/models.json"
    dotpi_link_force_symlink "../../shared/settings.json" "$d/settings.json"
    dotpi_link_force_symlink "$overlay/$name/bin" "$d/bin"
    dotpi_link_extension_bundle "$shared_dir/extensions-common" "$d/extensions" "../../../shared/extensions-common"
    dotpi_link_extension_helpers "$d/extensions" "../../../shared/extensions"

    dotpi_link_overlay_entries "$overlay" "$d" "$name"

    link="$bin_dir/$name"
    if [ "$name" != "todo" ]; then
      dotpi_link_force_symlink "../../dispatch-agent" "$link"
    fi
  done

  dotpi_link_force_symlink "../../dotpi" "$bin_dir/dotpi"

  if [ -d "$dot_pi_dir/agents/todo" ]; then
    dotpi_link_force_symlink "../../dispatch-agent" "$bin_dir/todo"
  else
    dotpi_link_force_symlink "../utilities/todo/todo" "$bin_dir/todo"
  fi

  for link in "$bin_dir"/*; do
    [ -L "$link" ] || continue
    name=$(basename "$link")
    [ "$name" = "dotpi" ] && continue
    [ "$name" = "todo" ] && continue
    target=$(readlink "$link" 2>/dev/null || true)
    case "$target" in
      ../../dispatch-agent|*/dispatch-agent)
        [ -d "$dot_pi_dir/agents/$name" ] || rm -f "$link"
        ;;
    esac
  done

  printf 'postinstall: dot-pi package root: %s\n' "$dot_pi_dir"
  printf 'postinstall: overlay: %s\n' "$overlay"
  printf 'postinstall: add to PATH if needed: export PATH="%s:$PATH"\n' "$bin_dir"
  [ -n "$pi_agent_dir" ] && true
}
