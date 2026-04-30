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

link_extension_bundle "$SHARED_DIR/extensions-common" "$mas_dir/extensions" "../../../shared/extensions-common"
ln -sfn "../../../shared/extensions/agent-orchestrator" "$mas_dir/extensions/agent-orchestrator"

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

$mas_name multi-agent system. Edit this file for a human-readable overview of the orchestrator and workflow. **USAGE.md** is shown for \`$mas_name help\` (and \`-h\` / \`--help\`) — keep that file man-page style for the launcher.

## Usage

\`\`\`
$mas_name - "your task"       # send prompt and stay interactive
$mas_name -p "task"           # print final reply and exit
$mas_name -p -v "task"        # print final reply plus progress
$mas_name ls                  # list past workspaces (if workspace MAS)
$mas_name resume              # resume latest workspace
$mas_name -h                  # show USAGE.md
\`\`\`
README

_usage_title=$(printf '%s' "$mas_name" | tr '[:lower:]' '[:upper:]')
if [ "$workspace" = true ]; then
  cat > "$mas_dir/USAGE.md" <<USAGE
${_usage_title}(1)                          dot-pi                          ${_usage_title}(1)

NAME
       $mas_name — multi-agent orchestrator (workspace mode)

SYNOPSIS
       $mas_name help | usage | -h | --help

       $mas_name
       $mas_name [-n name | --name name] - prompt words...
       $mas_name -p [-n name | --name name] prompt words...
       $mas_name -p -v [-n name | --name name] prompt words...

       $mas_name ls

       $mas_name resume [workspace-prefix]
       $mas_name resume [workspace-prefix] - prompt words...
       $mas_name resume [workspace-prefix] -p prompt words...

DESCRIPTION
       Coordinates subagents under agents/$mas_name/agents/.  Each fresh
       launch creates workspaces/$mas_name/<timestamp>/ (optional --name
       slug).  Subagent prompts use each subagent’s README.md and USAGE.md
       (orchestrator reads contracts via agent-orchestrator).

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

       --batch
              Compatibility alias for -p.  Prefer -p in new scripts.

       -n name, --name name
              Slug suffix for the new workspace directory.

COMMANDS
       help, usage, -h, --help
              Print this file on standard output.

       ls     List workspaces.

       resume [workspace-prefix]
              Resume latest or a workspace matching the prefix.

FILES
       workspaces/$mas_name/<timestamp>[--<slug>]/
              Workspace root (edit bootstrap.sh for layout).

SEE ALSO
       agents/$mas_name/README.md, agents/$mas_name/SYSTEM.md
USAGE
else
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

DESCRIPTION
       Coordinates subagents under agents/$mas_name/agents/.  Runs in the
       current working directory unless you add workspace bootstrap later.

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

       --batch
              Compatibility alias for -p.  Prefer -p in new scripts.

COMMANDS
       help, usage, -h, --help
              Print this file on standard output.

SEE ALSO
       agents/$mas_name/README.md, agents/$mas_name/SYSTEM.md
USAGE
fi

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
  cat > "$mas_dir/bootstrap.sh" <<'BOOTSTRAP'
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

echo "Created $mode_label MAS at $mas_dir"
echo ""
echo "Directory layout:"
echo "  $mas_dir/"
echo "    extensions/          (common bundle plus MAS-specific agent-orchestrator)"
echo "    agents/              (add or link subagent config directories here)"
echo "    USAGE.md             (man-style text for mas help / -h / --help)"
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
[ "$workspace" = true ] && echo "    bootstrap.sh         (workspace setup, environment, and preflight checks)"
echo ""
echo "Next steps:"
echo "  1. Add or link subagent config directories under $mas_dir/agents/"
echo "  2. Edit $mas_dir/USAGE.md (launcher CLI) and $mas_dir/SYSTEM.md with the orchestrator workflow"
if [ "$workspace" = true ]; then
  echo "  3. Link skills as needed: dotpi link-skill $mas_name <skill>"
  echo "  4. Edit bootstrap.sh to configure workspace directories, environment, and preflight checks"
  echo "  5. Run: $mas_name \"your task\""
else
  echo "  3. Link skills as needed: dotpi link-skill $mas_name <skill>"
  echo "  4. Run: $mas_name \"your task\""
fi

source "$COMMANDS_DIR/sync.sh"
