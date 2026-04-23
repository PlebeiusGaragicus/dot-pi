# dotpi list — list existing teams and standalone agents
# Sourced by the dotpi dispatcher — do not execute directly.

found=0

echo "Teams:"
for dir in "$DOT_PI_DIR"/teams/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  found=1
  agent_count=$(find "$dir/agents" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  prompt_count=$(find "$dir/prompts" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  mode="in-situ"
  [ -f "$dir/workspace.conf" ] && mode="workspace"
  ext_ok="no"
  [ -e "$dir/extensions/subagent-teams/index.ts" ] && ext_ok="yes"
  echo "  $name  ($mode, $agent_count agents, $prompt_count prompts, extensions linked: $ext_ok)"
done
if [ "$found" -eq 0 ]; then
  echo "  (none -- run 'dotpi create <name>' to create one)"
fi

echo ""
echo "Standalone agents:"
agent_found=0
for dir in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$dir" ] || continue
  name=$(basename "$dir")
  agent_found=1
  mode="in-situ"
  [ -f "$dir/workspace.conf" ] && mode="workspace"
  ext_count=$(find "$dir/extensions" -maxdepth 2 -name 'index.ts' 2>/dev/null | wc -l | tr -d ' ')
  echo "  $name  ($mode, extensions: $ext_count)"
done
if [ "$agent_found" -eq 0 ]; then
  echo "  (none -- run 'dotpi create-agent <name>' to create one)"
fi
