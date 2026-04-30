READER(1)                         dot-pi                         READER(1)

NAME
       reader — PDF OCR multi-agent system (workspace)

SYNOPSIS
       reader help | usage | -h | --help

       reader
       reader [--batch] [-n name | --name name] - prompt words...

       reader ls

       reader resume [workspace-prefix]
       reader resume [workspace-prefix] [--batch] - prompt words...

DESCRIPTION
       Renders PDFs to page images, OCRs with vision subagents, and writes
       per-page markdown under a dated workspace in workspaces/reader/.
       Subagent contracts live under agents/reader/agents/*/USAGE.md.

OPTIONS
       --batch
              Non-interactive run with a required prompt after -.

       -n name, --name name
              Slug suffix for the new workspace directory.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

       ls     List reader workspaces.

       resume [workspace-prefix]
              Resume latest or a workspace matching the prefix.

FILES
       workspaces/reader/<timestamp>[--<slug>]/
              pages/*.png, pages/*.md, reader-manifest.json, document.md,
              summary.md, sessions/, etc.

SEE ALSO
       agents/reader/README.md, agents/reader/SYSTEM.md,
       docs/multi-agent-systems/reader.md
