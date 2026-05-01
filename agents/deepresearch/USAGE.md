DEEPRESEARCH(1)                   dot-pi                   DEEPRESEARCH(1)

NAME
       deepresearch — deep research multi-agent system (workspace)

SYNOPSIS
       deepresearch help | usage | -h | --help

       deepresearch
       deepresearch [-n name | --name name] - prompt words...
       deepresearch -p [-n name | --name name] prompt words...
       deepresearch -p -v [-n name | --name name] prompt words...

       deepresearch ls

       deepresearch resume [workspace-name-or-path]
       deepresearch resume [workspace-name-or-path] - prompt words...
       deepresearch resume [workspace-name-or-path] -p prompt words...

DESCRIPTION
       Orchestrates subagents to search, collect evidence, and produce a
       report.  Each fresh launch creates workspaces/deepresearch/<timestamp>/
       (optionally with a --name slug).  Session logs may live under the
       workspace when sessions/ is present.

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

       -n name, --name name
              Append a slug to the new workspace directory name.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

       ls     List workspaces under workspaces/deepresearch/.

       resume [workspace-name-or-path]
              With no argument, choose a workspace by number.  With an
              argument, resume the exact workspace basename or path.

FILES
       workspaces/deepresearch/<timestamp>[--<slug>]/
              Run artifacts, drafts, sources, sessions as configured.

SEE ALSO
       agents/deepresearch/README.md, agents/deepresearch/SYSTEM.md,
       docs/multi-agent-systems/deepresearch.md
