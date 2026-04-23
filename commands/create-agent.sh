# dotpi create-agent — create a standalone agent directory with a stub extension
# Sourced by the dotpi dispatcher — do not execute directly.

workspace=false
if [ "${1:-}" = "--workspace" ]; then
  workspace=true
  shift
fi

[ $# -lt 1 ] && { echo "Error: agent name required"; exit 1; }
agent_name="$1"
agent_dir="$DOT_PI_DIR/agents/$agent_name"

if [ -d "$agent_dir" ]; then
  echo "Error: agent '$agent_name' already exists at $agent_dir"
  exit 1
fi

echo "Creating standalone agent '$agent_name'..."
mkdir -p "$agent_dir/extensions/$agent_name" "$agent_dir/skills" "$agent_dir/sessions" "$agent_dir/prompts"

ln -sf "../../../shared/prompts/help.md" "$agent_dir/prompts/help.md"

ln -sf "../../../shared/extensions/run-finish-notify" "$agent_dir/extensions/run-finish-notify"
ln -sf "../../../shared/extensions/startup-branding" "$agent_dir/extensions/startup-branding"
ln -sf "../../../shared/extensions/say" "$agent_dir/extensions/say"
ln -sf "../../../shared/extensions/save" "$agent_dir/extensions/save"

cat > "$agent_dir/extensions/$agent_name/index.ts" <<'STUB'
import type { ExtensionAPI } from "@mariozechner/pi-coding-agent";

export default function (pi: ExtensionAPI) {
	// Add lifecycle hooks and custom tools here.
	// See docs/reference/extensions.md for the extension API.
}
STUB

mkdir -p "$agent_dir/themes"
for theme in "$SHARED_DIR"/themes/*.json; do
  [ -f "$theme" ] || continue
  ln -sf "../../../shared/themes/$(basename "$theme")" "$agent_dir/themes/$(basename "$theme")"
done

mkdir -p "$SHARED_DIR/bin"
ln -sf "../../shared/bin" "$agent_dir/bin"

ln -sf "../../shared/models.json" "$agent_dir/models.json"

ln -sf "../../shared/settings.json" "$agent_dir/settings.json"

cat > "$agent_dir/pi-args" <<'PIARGS'
# Optional default CLI flags for `p <name>` (read by bash_aliases). One flag per line; # starts a comment.
#
# IMPORTANT: must end with a newline (this comment also works) or last line will be ignored
PIARGS

cat > "$agent_dir/SYSTEM.md" <<SYSTEMMD
# Edit the body below. Pi loads this file as your system prompt (replaces the default).

You are a helpful assistant for the **$agent_name** agent. Describe your role, tone, and constraints here.
SYSTEMMD

if command -v figlet &>/dev/null; then
  { figlet -f small "$agent_name"; echo "---"; echo "Agent: $agent_name"; } > "$agent_dir/banner.txt"
  echo "Generated banner.txt (edit to customize)"
else
  echo "Warning: figlet not installed -- skipping banner.txt (brew install figlet)"
fi

if [ "$workspace" = true ]; then
  cat > "$agent_dir/workspace.conf" <<'WSCONF'
# Subdirectories to pre-create in each workspace run.
# One directory name per line. The alias reads this file
# and runs mkdir -p for each entry before launching pi.
#
# IMPORTANT: must end with a newline (this comment also works) or last line will be ignored
WSCONF
  echo "Created workspace.conf (edit to add workspace subdirectories)"
fi

mode_label="in-situ"
[ "$workspace" = true ] && mode_label="workspace"

echo "Created $mode_label standalone agent at $agent_dir"
echo ""
echo "Directory layout:"
echo "  $agent_dir/"
echo "    extensions/              ($agent_name/, run-finish-notify, startup-branding, say.ts)"
echo "    skills/                  (empty — use dotpi link-skill $agent_name <skill>)"
echo "    prompts/                 (shared help.md symlinked; add agent-specific prompts here)"
echo "    themes/                  (individual themes symlinked from shared)"
echo "    bin/                     (symlinked to shared/bin, gitignored contents)"
echo "    sessions/                (runtime session data, gitignored)"
echo "    models.json              (symlinked to shared)"
echo "    settings.json            (symlink → shared/settings.json)"
echo "    pi-args                  (optional default CLI flags; see IMPORTANT line inside)"
echo "    SYSTEM.md                (system prompt — edit to customize)"
echo "    banner.txt               (startup branding -- edit to customize)"
[ "$workspace" = true ] && echo "    workspace.conf           (workspace subdirectory list)"
echo ""
echo "Next steps:"
echo "  1. Edit $agent_dir/SYSTEM.md (and optionally pi-args)"
echo "  2. Edit $agent_dir/extensions/$agent_name/index.ts if you need custom tools"
echo "  3. Link skills as needed: dotpi link-skill $agent_name <skill>"
if [ "$workspace" = true ]; then
  echo "  4. Edit workspace.conf to list subdirectories for each run"
  echo "  5. Source bash_aliases and invoke: p $agent_name \"your task\""
else
  echo "  4. Source bash_aliases and invoke: p $agent_name \"your task\""
fi
