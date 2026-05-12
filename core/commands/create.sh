# dotpi create — create a new in-situ multi-agent system with shared extension symlinks
# Sourced by the dotpi dispatcher — do not execute directly.

[ $# -lt 1 ] && { echo "Error: MAS name required"; exit 1; }
mas_name="$1"
mas_dir="$DOT_PI_DIR/agents/$mas_name"

if [ -d "$mas_dir" ]; then
  echo "Error: agent '$mas_name' already exists at $mas_dir"
  exit 1
fi

echo "Creating multi-agent system '$mas_name'..."
mkdir -p "$mas_dir/extensions" "$mas_dir/prompts" "$mas_dir/skills"

ln -sf "../../../shared/prompts/introduction.md" "$mas_dir/prompts/introduction.md"

link_extension_bundle "$SHARED_DIR/extensions-common" "$mas_dir/extensions" "../../../shared/extensions-common"
ln -sfn "../../../shared/extensions/top-level-agent-orchestrator" "$mas_dir/extensions/top-level-agent-orchestrator"

mkdir -p "$mas_dir/themes"
for theme in "$SHARED_DIR"/themes/*.json; do
  [ -f "$theme" ] || continue
  ln -sf "../../../shared/themes/$(basename "$theme")" "$mas_dir/themes/$(basename "$theme")"
done

mkdir -p "$SHARED_DIR/bin"
ln -sf "../../shared/bin" "$mas_dir/bin"

ln -sf "../../shared/models.json" "$mas_dir/models.json"

ln -sf "../../shared/auth.json" "$mas_dir/auth.json"

ln -sf "../../shared/settings.json" "$mas_dir/settings.json"

cat > "$mas_dir/README.md" <<README
# $mas_name

$mas_name multi-agent system. Edit this file for a human-readable overview of the orchestrator and workflow. **USAGE.md** is shown for \`$mas_name help\` (and \`-h\` / \`--help\`) — keep that file man-page style for the launcher.

This scaffold uses the **top-level-agent-orchestrator** extension: the \`subagent\` tool delegates to the fixed capability agents \`ask\`, \`scout\`, \`writer\`, \`coder\`, and \`web\` (each a separate top-level agent config shipped in this repo). Use \`prompts/\` for workflow templates that orchestrate those workers.

## Usage

\`\`\`
$mas_name - "your task"       # send prompt and stay interactive
$mas_name -p "task"           # print final reply and exit
$mas_name -p -v "task"        # print final reply plus progress
$mas_name ls                  # list sessions for the current directory
$mas_name -h                  # show USAGE.md
\`\`\`
README

_usage_title=$(printf '%s' "$mas_name" | tr '[:lower:]' '[:upper:]')
cat > "$mas_dir/USAGE.md" <<USAGE
${_usage_title}(1)                          dot-pi                          ${_usage_title}(1)

NAME
       $mas_name — multi-agent orchestrator (in-situ)

SYNOPSIS
       $mas_name help | usage | -h | --help

       $mas_name
       $mas_name - prompt words...
       $mas_name -p prompt words...
       $mas_name -p -v prompt words...
       $mas_name ls

DESCRIPTION
       $mas_name launches pi with top-level-agent-orchestrator. It delegates
       bounded tasks to the curated top-level capability agents ask, scout,
       writer, coder, and web through the subagent tool.

       The agent runs in the current working directory. Resumable sessions and
       worker traces live under DOT_PI_OVERLAY (see agents/mas/USAGE.md on the
       shipped mas agent for path conventions).

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

COMMANDS
       help, usage, -h, --help
              Print this file on standard output.

       ls     List sessions for this agent and current directory.

SEE ALSO
       agents/$mas_name/README.md, agents/$mas_name/SYSTEM.md
USAGE

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

You are the orchestrator for the $mas_name multi-agent system. Delegate bounded work to the top-level capability agents \`ask\`, \`scout\`, \`writer\`, \`coder\`, and \`web\` through the \`subagent\` tool (parallel, chain, or single mode per the tool schema). Synthesize worker results and present the final answer to the user.

Worker capabilities and personas are defined in each worker's config (e.g. CAPABILITY.md, SYSTEM.md, USAGE.md under \`agents/<worker>/\`). Add workflow templates under \`prompts/\` and slash-invoke them as needed.
SYSTEMMD
echo "Created SYSTEM.md (edit to customize)"

echo "Created MAS at $mas_dir"
echo ""
echo "Directory layout:"
echo "  $mas_dir/"
echo "    extensions/          (common bundle plus top-level-agent-orchestrator)"
echo "    USAGE.md             (man-style text for $mas_name help / -h / --help)"
echo "    prompts/             (shared introduction.md symlinked; add workflow templates here)"
echo "    skills/              (empty — use dotpi link-skill $mas_name <skill>)"
echo "    themes/              (individual themes symlinked from shared)"
echo "    bin/                 (symlinked to shared/bin, gitignored contents)"
echo "    sessions/            (not used; sessions live under DOT_PI_OVERLAY)"
echo "    SYSTEM.md            (orchestrator system prompt)"
echo "    banner.txt           (startup branding -- edit to customize)"
echo "    models.json          (symlinked to shared)"
echo "    auth.json            (symlink → shared/auth.json)"
echo "    settings.json        (symlink → shared/settings.json)"
echo "    pi-args              (optional default CLI flags; see IMPORTANT line inside)"
echo ""
echo "Next steps:"
echo "  1. Edit $mas_dir/USAGE.md (launcher CLI) and $mas_dir/SYSTEM.md with the orchestrator workflow"
echo "  2. Add prompt templates under $mas_dir/prompts/ as needed"
echo "  3. Link skills: dotpi link-skill $mas_name <skill>"
echo "  4. Run: $mas_name \"your task\""

source "$COMMANDS_DIR/sync.sh"
