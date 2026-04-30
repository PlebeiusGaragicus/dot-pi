DEEPRESEARCH(1)                   dot-pi                   DEEPRESEARCH(1)

NAME
       deepresearch — deep research multi-agent system (workspace)

SYNOPSIS
       deepresearch help | usage | -h | --help

       deepresearch
       deepresearch [--batch] [-n name | --name name] - prompt words...

       deepresearch ls

       deepresearch resume [workspace-prefix]
       deepresearch resume [workspace-prefix] [--batch] - prompt words...

       Leading --batch is accepted before other arguments when paired with
       a prompt as documented by dispatch-agent.

DESCRIPTION
       Orchestrates subagents to search, collect evidence, and produce a
       report.  Each fresh launch creates workspaces/deepresearch/<timestamp>/
       (optionally with a --name slug).  Session logs may live under the
       workspace when sessions/ is present.

OPTIONS
       --batch
              One-shot style launch with a required prompt (after -) or
              equivalent stdin handling.

       -n name, --name name
              Append a slug to the new workspace directory name.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

       ls     List workspaces under workspaces/deepresearch/.

       resume [workspace-prefix]
              Continue the latest workspace or match a directory prefix.

FILES
       workspaces/deepresearch/<timestamp>[--<slug>]/
              Run artifacts, drafts, sources, sessions as configured.

SEE ALSO
       agents/deepresearch/README.md, agents/deepresearch/SYSTEM.md,
       docs/multi-agent-systems/deepresearch.md, run-retro deepresearch
