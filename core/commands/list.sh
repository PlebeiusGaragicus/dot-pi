# dotpi list — list existing agent configs
# Sourced by the dotpi dispatcher — do not execute directly.

mas_found=0
standalone_found=0

echo "Multi-agent systems:"
for dir in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$dir" ] || continue
  if [ ! -e "$dir/extensions/top-level-agent-orchestrator/index.ts" ]; then
    continue
  fi
  name=$(basename "$dir")
  mas_found=1
  prompt_count=0
  [ -d "$dir/prompts" ] && prompt_count=$(find "$dir/prompts" -maxdepth 1 -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
  echo "  $name  ($prompt_count prompts, top-level MAS)"
done
if [ "$mas_found" -eq 0 ]; then
  echo "  (none -- add agents/<name>/ per docs/reference/creating-a-new-agent.md, then dotpi relink)"
fi

echo ""
echo "Standalone agents:"
for dir in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$dir" ] || continue
  if [ -e "$dir/extensions/top-level-agent-orchestrator/index.ts" ]; then
    continue
  fi
  name=$(basename "$dir")
  standalone_found=1
  ext_count=$(find "$dir/extensions" -maxdepth 2 -name 'index.ts' 2>/dev/null | wc -l | tr -d ' ')
  echo "  $name  (extensions: $ext_count)"
done
if [ "$standalone_found" -eq 0 ]; then
  echo "  (none -- add agents/<name>/ per docs/reference/creating-a-new-agent.md, then dotpi relink)"
fi

echo ""
echo "Each entry above is a command on PATH via the installed dot-pi core/bin directory."
echo "Run 'dotpi relink' to refresh local symlinks after manual changes."
