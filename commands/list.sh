# dotpi list — list existing agent configs
# Sourced by the dotpi dispatcher — do not execute directly.

found=0
team_found=0
standalone_found=0

echo "Teams:"
for dir in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$dir" ] || continue
  [ -e "$dir/extensions/subagent-teams/index.ts" ] || [ -f "$dir/team-prompt.md" ] || continue
  name=$(basename "$dir")
  found=1
  team_found=1
  agent_count=$(find "$dir/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  prompt_count=$(find "$dir/prompts" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  mode="in-situ"
  [ -f "$dir/workspace.conf" ] && mode="workspace"
  ext_ok="no"
  [ -e "$dir/extensions/subagent-teams/index.ts" ] && ext_ok="yes"
  echo "  $name  ($mode, $agent_count agents, $prompt_count prompts, extensions linked: $ext_ok)"
done
if [ "$team_found" -eq 0 ]; then
  echo "  (none -- run 'dotpi create <name>' to create one)"
fi

echo ""
echo "Standalone agents:"
for dir in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$dir" ] || continue
  if [ -e "$dir/extensions/subagent-teams/index.ts" ] || [ -f "$dir/team-prompt.md" ]; then
    continue
  fi
  name=$(basename "$dir")
  found=1
  standalone_found=1
  mode="in-situ"
  [ -f "$dir/workspace.conf" ] && mode="workspace"
  ext_count=$(find "$dir/extensions" -maxdepth 2 -name 'index.ts' 2>/dev/null | wc -l | tr -d ' ')
  echo "  $name  ($mode, extensions: $ext_count)"
done
if [ "$standalone_found" -eq 0 ]; then
  echo "  (none -- run 'dotpi create-agent <name>' to create one)"
fi

echo ""
echo "Each entry above is a command on PATH (via ~/.dot-pi/bin/)."
echo "Run 'dotpi sync' to refresh symlinks after manual changes."
