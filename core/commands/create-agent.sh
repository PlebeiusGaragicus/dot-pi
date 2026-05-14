# dotpi create-agent — create an in-situ standalone agent directory with a stub extension
# Sourced by the dotpi dispatcher — do not execute directly.

[ $# -lt 1 ] && { echo "Error: agent name required"; exit 1; }
agent_name="$1"
agent_dir="$DOT_PI_DIR/agents/$agent_name"

if [ -d "$agent_dir" ]; then
  echo "Error: agent '$agent_name' already exists at $agent_dir"
  exit 1
fi

echo "Creating standalone agent '$agent_name'..."
mkdir -p "$agent_dir/extensions/$agent_name" "$agent_dir/skills" "$agent_dir/prompts"

ln -sf "../../../shared/prompts/introduction.md" "$agent_dir/prompts/introduction.md"

link_extension_bundle "$SHARED_DIR/extensions-common" "$agent_dir/extensions" "../../../shared/extensions-common"

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

ln -sf "../../shared/auth.json" "$agent_dir/auth.json"

ln -sf "../../shared/settings.json" "$agent_dir/settings.json"

cat > "$agent_dir/README.md" <<README
# $agent_name

$agent_name standalone agent. Edit this file for a human-readable overview, design notes, and links. **USAGE.md** is shown for \`$agent_name help\` (and \`-h\` / \`--help\`) — keep that file man-page style for the launcher.

## Usage

\`\`\`
$agent_name                     # interactive session
$agent_name - "your prompt"     # send prompt and stay interactive
$agent_name -p "prompt"         # print final reply and exit
$agent_name -p -v "prompt"      # print final reply plus progress
echo "input" | $agent_name -p   # pipe input as prompt
$agent_name ls                  # list sessions for the current directory
$agent_name -h                  # show USAGE.md
\`\`\`
README

_usage_title=$(printf '%s' "$agent_name" | tr '[:lower:]' '[:upper:]')
cat > "$agent_dir/USAGE.md" <<USAGE
${_usage_title}(1)                          dot-pi                          ${_usage_title}(1)

NAME
       $agent_name — standalone agent

SYNOPSIS
       $agent_name help | usage | -h | --help

       $agent_name
       $agent_name - prompt words...
       $agent_name -p prompt words...
       $agent_name -p -v prompt words...
       $agent_name ls

DESCRIPTION
       Runs pi with this config in the current working directory.  Session
       files are stored outside the package clone under DOT_PI_OVERLAY.

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
       agents/$agent_name/README.md, agents/$agent_name/SYSTEM.md
USAGE

cat > "$agent_dir/pi-args" <<'PIARGS'
# Default CLI flags (read by dispatch-agent). One flag per line; # starts a comment.
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

echo "Created standalone agent at $agent_dir"
echo ""
echo "Directory layout:"
echo "  $agent_dir/"
echo "    extensions/              ($agent_name/ plus common extension bundle)"
echo "    skills/                  (empty — use dotpi link-skill $agent_name <skill>)"
echo "    prompts/                 (shared introduction.md symlinked; add agent-specific prompts here)"
echo "    USAGE.md                 (man-style text for agent help / -h / --help)"
echo "    themes/                  (individual themes symlinked from shared)"
echo "    bin/                     (symlinked to shared/bin, gitignored contents)"
echo "    sessions/                (not used; sessions live under DOT_PI_OVERLAY)"
echo "    models.json              (symlinked to shared)"
echo "    auth.json                (symlink → shared/auth.json)"
echo "    settings.json            (symlink → shared/settings.json)"
echo "    pi-args                  (optional default CLI flags; see IMPORTANT line inside)"
echo "    SYSTEM.md                (system prompt — edit to customize)"
echo "    banner.txt               (startup branding -- edit to customize)"
echo ""
echo "Next steps:"
echo "  1. Edit $agent_dir/USAGE.md (launcher help) and $agent_dir/SYSTEM.md (and optionally pi-args)"
echo "  2. Edit $agent_dir/extensions/$agent_name/index.ts if you need custom tools"
echo "  3. Link skills as needed: dotpi link-skill $agent_name <skill>"
echo "  4. Run: $agent_name \"your task\""

source "$COMMANDS_DIR/relink.sh"
