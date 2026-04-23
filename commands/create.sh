# dotpi create — create a new team directory with shared extension symlinks
# Sourced by the dotpi dispatcher — do not execute directly.

workspace=false
if [ "${1:-}" = "--workspace" ]; then
  workspace=true
  shift
fi

[ $# -lt 1 ] && { echo "Error: team name required"; exit 1; }
team_name="$1"
team_dir="$DOT_PI_DIR/teams/$team_name"

if [ -d "$team_dir" ]; then
  echo "Error: team '$team_name' already exists at $team_dir"
  exit 1
fi

echo "Creating team '$team_name'..."
mkdir -p "$team_dir/extensions" "$team_dir/agents" "$team_dir/prompts" "$team_dir/skills" "$team_dir/sessions"

ln -sf "../../../shared/prompts/help.md" "$team_dir/prompts/help.md"

ln -sf "../../../shared/extensions/subagent-teams" "$team_dir/extensions/subagent-teams"
ln -sf "../../../shared/extensions/run-finish-notify" "$team_dir/extensions/run-finish-notify"
ln -sf "../../../shared/extensions/startup-branding" "$team_dir/extensions/startup-branding"
ln -sf "../../../shared/extensions/save" "$team_dir/extensions/save"

mkdir -p "$team_dir/themes"
for theme in "$SHARED_DIR"/themes/*.json; do
  [ -f "$theme" ] || continue
  ln -sf "../../../shared/themes/$(basename "$theme")" "$team_dir/themes/$(basename "$theme")"
done

mkdir -p "$SHARED_DIR/bin"
ln -sf "../../shared/bin" "$team_dir/bin"

ln -sf "../../shared/models.json" "$team_dir/models.json"

ln -sf "../../shared/settings.json" "$team_dir/settings.json"

cat > "$team_dir/README.md" <<README
# $team_name

$team_name agent team. Edit this file to describe what this team does.

## Usage

\`\`\`
$team_name "your task"         # new session
$team_name --list              # list past workspaces (if workspace team)
$team_name --resume            # resume latest workspace
$team_name -h                  # show this help
\`\`\`
README

cat > "$team_dir/pi-args" <<'PIARGS'
# Default CLI flags (read by dispatch-agent). One flag per line; # starts a comment.
#
# IMPORTANT: must end with a newline (this comment also works) or last line will be ignored
PIARGS

if command -v figlet &>/dev/null; then
  { figlet -f small "$team_name"; echo "---"; echo "Team: $team_name"; } > "$team_dir/banner.txt"
  echo "Generated banner.txt (edit to customize)"
else
  echo "Warning: figlet not installed -- skipping banner.txt (brew install figlet)"
fi

cat > "$team_dir/team-prompt.md" <<TEAMPROMPT
---
name: $(echo "$team_name" | sed 's/./\U&/')
description: $team_name agent team.
# tools: read, grep, find, ls
# model: plebchat/qwen/qwen3-coder-next
---

# $team_name Team

You are the orchestrator for the $team_name team. Add your orchestrator prompt here.
TEAMPROMPT
echo "Created team-prompt.md (edit to customize)"

if [ "$workspace" = true ]; then
  cat > "$team_dir/workspace.conf" <<'WSCONF'
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

echo "Created $mode_label team at $team_dir"
echo ""
echo "Directory layout:"
echo "  $team_dir/"
echo "    extensions/          (symlinked to shared)"
echo "    agents/              (add your agent .md files here)"
echo "    prompts/             (add workflow prompt templates here)"
echo "    skills/              (empty — use dotpi link-skill $team_name <skill>)"
echo "    themes/              (individual themes symlinked from shared)"
echo "    bin/                 (symlinked to shared/bin, gitignored contents)"
echo "    sessions/            (runtime session data, gitignored)"
echo "    team-prompt.md       (orchestrator prompt with tools/model frontmatter)"
echo "    banner.txt           (startup branding -- edit to customize)"
echo "    models.json          (symlinked to shared)"
echo "    settings.json        (symlink → shared/settings.json)"
echo "    pi-args              (optional default CLI flags; see IMPORTANT line inside)"
[ "$workspace" = true ] && echo "    workspace.conf       (workspace subdirectory list)"
echo ""
echo "Next steps:"
echo "  1. Add agent .md files to $team_dir/agents/"
echo "  2. Add prompt templates to $team_dir/prompts/"
if [ "$workspace" = true ]; then
  echo "  3. Link skills as needed: dotpi link-skill $team_name <skill>"
  echo "  4. Edit workspace.conf to list subdirectories for each run"
  echo "  5. Run: $team_name \"your task\""
else
  echo "  3. Link skills as needed: dotpi link-skill $team_name <skill>"
  echo "  4. Run: $team_name \"your task\""
fi

source "$COMMANDS_DIR/sync.sh"
