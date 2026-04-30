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

ln -sf "../../shared/settings.json" "$agent_dir/settings.json"

cat > "$agent_dir/README.md" <<README
# $agent_name

$agent_name standalone agent. Edit this file for a human-readable overview, design notes, and links. **USAGE.md** is shown for \`$agent_name help\` (and \`-h\` / \`--help\`) — keep that file man-page style for the launcher.

## Usage

\`\`\`
$agent_name                     # interactive session
$agent_name - "your prompt"     # send prompt and stay interactive
$agent_name --batch - "prompt"  # one-shot prompt, final text on stdout
echo "input" | $agent_name      # pipe input as prompt
$agent_name -h                  # show USAGE.md
\`\`\`
README

_usage_title=$(printf '%s' "$agent_name" | tr '[:lower:]' '[:upper:]')
if [ "$workspace" = true ]; then
  cat > "$agent_dir/USAGE.md" <<USAGE
${_usage_title}(1)                          dot-pi                          ${_usage_title}(1)

NAME
       $agent_name — standalone agent (workspace mode)

SYNOPSIS
       $agent_name help | usage | -h | --help

       $agent_name
       $agent_name [--batch] [-n name | --name name] - prompt words...

       $agent_name ls

       $agent_name resume [workspace-prefix]
       $agent_name resume [workspace-prefix] [--batch] - prompt words...

DESCRIPTION
       Fresh launches create workspaces/$agent_name/<timestamp>/ (with an
       optional --name slug).  Edit bootstrap.sh to export env vars and
       prepare directories.

OPTIONS
       --batch
              Non-interactive run; requires a prompt after - (or piped
              stdin where supported).

       -n name, --name name
              Slug suffix for the new workspace directory.

COMMANDS
       help, usage, -h, --help
              Print this file on standard output.

       ls     List workspaces.

       resume [workspace-prefix]
              Resume latest or a workspace matching the prefix.

FILES
       workspaces/$agent_name/<timestamp>[--<slug>]/
              Workspace root (edit bootstrap.sh for layout).

SEE ALSO
       agents/$agent_name/README.md, agents/$agent_name/SYSTEM.md
USAGE
else
  cat > "$agent_dir/USAGE.md" <<USAGE
${_usage_title}(1)                          dot-pi                          ${_usage_title}(1)

NAME
       $agent_name — standalone agent (in-situ)

SYNOPSIS
       $agent_name help | usage | -h | --help

       $agent_name
       $agent_name [--batch] - prompt words...

DESCRIPTION
       Runs pi with this config in the current working directory.

OPTIONS
       --batch
              Non-interactive run; requires a prompt after - (or piped
              stdin where supported).

COMMANDS
       help, usage, -h, --help
              Print this file on standard output.

SEE ALSO
       agents/$agent_name/README.md, agents/$agent_name/SYSTEM.md
USAGE
fi

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

if [ "$workspace" = true ]; then
  cat > "$agent_dir/bootstrap.sh" <<'BOOTSTRAP'
#!/usr/bin/env bash

WORKSPACE_AGENT=1
export WORKSPACE_AGENT

if [ -z "${WORKSPACE_DIR:-}" ]; then
  echo "bootstrap: WORKSPACE_DIR is required" >&2
  return 1
fi

mkdir -p "$WORKSPACE_DIR/sessions"

echo "bootstrap: workspace ready at $WORKSPACE_DIR"
BOOTSTRAP
  echo "Created bootstrap.sh (edit to add directories, environment, and preflight checks)"
fi

mode_label="in-situ"
[ "$workspace" = true ] && mode_label="workspace"

echo "Created $mode_label standalone agent at $agent_dir"
echo ""
echo "Directory layout:"
echo "  $agent_dir/"
echo "    extensions/              ($agent_name/ plus common extension bundle)"
echo "    skills/                  (empty — use dotpi link-skill $agent_name <skill>)"
echo "    prompts/                 (shared help.md symlinked; add agent-specific prompts here)"
echo "    USAGE.md                 (man-style text for agent help / -h / --help)"
echo "    themes/                  (individual themes symlinked from shared)"
echo "    bin/                     (symlinked to shared/bin, gitignored contents)"
echo "    sessions/                (runtime session data, gitignored)"
echo "    models.json              (symlinked to shared)"
echo "    settings.json            (symlink → shared/settings.json)"
echo "    pi-args                  (optional default CLI flags; see IMPORTANT line inside)"
echo "    SYSTEM.md                (system prompt — edit to customize)"
echo "    banner.txt               (startup branding -- edit to customize)"
[ "$workspace" = true ] && echo "    bootstrap.sh             (workspace setup, environment, and preflight checks)"
echo ""
echo "Next steps:"
echo "  1. Edit $agent_dir/USAGE.md (launcher help) and $agent_dir/SYSTEM.md (and optionally pi-args)"
echo "  2. Edit $agent_dir/extensions/$agent_name/index.ts if you need custom tools"
echo "  3. Link skills as needed: dotpi link-skill $agent_name <skill>"
if [ "$workspace" = true ]; then
  echo "  4. Edit bootstrap.sh to configure workspace directories, environment, and preflight checks"
  echo "  5. Run: $agent_name \"your task\""
else
  echo "  4. Run: $agent_name \"your task\""
fi

source "$COMMANDS_DIR/sync.sh"
