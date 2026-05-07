# dotpi list — list existing agent configs
# Sourced by the dotpi dispatcher — do not execute directly.

mas_found=0
standalone_found=0

echo "Multi-agent systems:"
for dir in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$dir" ] || continue
  if [ ! -e "$dir/extensions/agent-orchestrator/index.ts" ] && [ ! -e "$dir/extensions/top-level-agent-orchestrator/index.ts" ]; then
    continue
  fi
  name=$(basename "$dir")
  mas_found=1
  agent_count=0
  [ -d "$dir/agents" ] && agent_count=$(find "$dir/agents" -mindepth 1 -maxdepth 1 \( -type d -o -type l \) 2>/dev/null | wc -l | tr -d ' ')
  prompt_count=0
  [ -d "$dir/prompts" ] && prompt_count=$(find "$dir/prompts" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  mode="in-situ"
  agent_declares_workspace "$dir" && mode="workspace"
  orchestrator="nested"
  [ -e "$dir/extensions/top-level-agent-orchestrator/index.ts" ] && orchestrator="top-level"
  echo "  $name  ($mode, $agent_count subagents, $prompt_count prompts, orchestrator: $orchestrator)"
done
if [ "$mas_found" -eq 0 ]; then
  echo "  (none -- run 'dotpi create <name>' to create one)"
fi

echo ""
echo "Standalone agents:"
for dir in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$dir" ] || continue
  if [ -e "$dir/extensions/agent-orchestrator/index.ts" ] || [ -e "$dir/extensions/top-level-agent-orchestrator/index.ts" ]; then
    continue
  fi
  name=$(basename "$dir")
  standalone_found=1
  mode="in-situ"
  agent_declares_workspace "$dir" && mode="workspace"
  ext_count=$(find "$dir/extensions" -maxdepth 2 -name 'index.ts' 2>/dev/null | wc -l | tr -d ' ')
  echo "  $name  ($mode, extensions: $ext_count)"
done
if [ "$standalone_found" -eq 0 ]; then
  echo "  (none -- run 'dotpi create-agent <name>' to create one)"
fi

echo ""
echo "Each entry above is a command on PATH (via ~/.dot-pi/core/bin/)."
echo "Run 'dotpi sync' to refresh symlinks after manual changes."
