# dotpi create — create a new multi-agent system with shared extension symlinks
# Sourced by the dotpi dispatcher — do not execute directly.

workspace=false
if [ "${1:-}" = "--workspace" ]; then
  workspace=true
  shift
fi

[ $# -lt 1 ] && { echo "Error: MAS name required"; exit 1; }
mas_name="$1"
mas_dir="$DOT_PI_DIR/agents/$mas_name"

if [ -d "$mas_dir" ]; then
  echo "Error: agent '$mas_name' already exists at $mas_dir"
  exit 1
fi

echo "Creating multi-agent system '$mas_name'..."
mkdir -p "$mas_dir/extensions" "$mas_dir/agents" "$mas_dir/prompts" "$mas_dir/skills" "$mas_dir/sessions"

ln -sf "../../../shared/prompts/help.md" "$mas_dir/prompts/help.md"

ln -sf "../../../shared/extensions/agent-orchestrator" "$mas_dir/extensions/agent-orchestrator"
ln -sf "../../../shared/extensions/run-finish-notify" "$mas_dir/extensions/run-finish-notify"
ln -sf "../../../shared/extensions/startup-branding" "$mas_dir/extensions/startup-branding"
ln -sf "../../../shared/extensions/save" "$mas_dir/extensions/save"

mkdir -p "$mas_dir/themes"
for theme in "$SHARED_DIR"/themes/*.json; do
  [ -f "$theme" ] || continue
  ln -sf "../../../shared/themes/$(basename "$theme")" "$mas_dir/themes/$(basename "$theme")"
done

mkdir -p "$SHARED_DIR/bin"
ln -sf "../../shared/bin" "$mas_dir/bin"

ln -sf "../../shared/models.json" "$mas_dir/models.json"

ln -sf "../../shared/settings.json" "$mas_dir/settings.json"

cat > "$mas_dir/README.md" <<README
# $mas_name

$mas_name multi-agent system. Edit this file to describe the orchestrator, subagents, and workflow.

## Usage

\`\`\`
$mas_name "your task"         # new session
$mas_name --list              # list past workspaces (if workspace MAS)
$mas_name --resume            # resume latest workspace
$mas_name -h                  # show this help
\`\`\`
README

cat > "$mas_dir/pi-args" <<'PIARGS'
# Default CLI flags (read by dispatch-agent). One flag per line; # starts a comment.
PIARGS

if command -v figlet &>/dev/null; then
  { figlet -f small "$mas_name"; echo "---"; echo "MAS: $mas_name"; } > "$mas_dir/banner.txt"
  echo "Generated banner.txt (edit to customize)"
else
  echo "Warning: figlet not installed -- skipping banner.txt (brew install figlet)"
fi

cat > "$mas_dir/SYSTEM.md" <<SYSTEMMD
# $(echo "$mas_name" | sed 's/./\U&/') Orchestrator

You are the orchestrator for the $mas_name multi-agent system. Coordinate specialized subagents through the \`subagent\` tool, synthesize their results, and present the final answer to the user.

The available subagents and their invocation contracts are appended automatically by the \`agent-orchestrator\` extension from each linked subagent's \`USAGE.md\` file.
SYSTEMMD
echo "Created SYSTEM.md (edit to customize)"

if [ "$workspace" = true ]; then
  cat > "$mas_dir/workspace.conf" <<'WSCONF'
# Subdirectories to pre-create in each workspace run.
# One directory name per line. The alias reads this file
# and runs mkdir -p for each entry before launching pi.
WSCONF
  echo "Created workspace.conf (edit to add workspace subdirectories)"
fi

mode_label="in-situ"
[ "$workspace" = true ] && mode_label="workspace"

echo "Created $mode_label MAS at $mas_dir"
echo ""
echo "Directory layout:"
echo "  $mas_dir/"
echo "    extensions/          (symlinked to shared)"
echo "    agents/              (add or link subagent config directories here)"
echo "    prompts/             (add workflow prompt templates here)"
echo "    skills/              (empty — use dotpi link-skill $mas_name <skill>)"
echo "    themes/              (individual themes symlinked from shared)"
echo "    bin/                 (symlinked to shared/bin, gitignored contents)"
echo "    sessions/            (runtime session data, gitignored)"
echo "    SYSTEM.md            (orchestrator system prompt)"
echo "    banner.txt           (startup branding -- edit to customize)"
echo "    models.json          (symlinked to shared)"
echo "    settings.json        (symlink → shared/settings.json)"
echo "    pi-args              (optional default CLI flags; see IMPORTANT line inside)"
[ "$workspace" = true ] && echo "    workspace.conf       (workspace subdirectory list)"
echo ""
echo "Next steps:"
echo "  1. Add or link subagent config directories under $mas_dir/agents/"
echo "  2. Edit $mas_dir/SYSTEM.md with the orchestrator workflow"
if [ "$workspace" = true ]; then
  echo "  3. Link skills as needed: dotpi link-skill $mas_name <skill>"
  echo "  4. Edit workspace.conf to list subdirectories for each run"
  echo "  5. Run: $mas_name \"your task\""
else
  echo "  3. Link skills as needed: dotpi link-skill $mas_name <skill>"
  echo "  4. Run: $mas_name \"your task\""
fi

source "$COMMANDS_DIR/sync.sh"
