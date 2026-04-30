ASK(1)                            dot-pi                            ASK(1)

NAME
       ask — read-only explain agent for the current directory (in-situ)

SYNOPSIS
       ask help | usage | -h | --help

       ask
       ask [--batch] - prompt words...

DESCRIPTION
       ask launches pi configured for inspection of the current tree.  It
       should not modify files; tools and SYSTEM.md enforce read-only use.

OPTIONS
       --batch
              Non-interactive run.  Requires a prompt after - or piped stdin.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       ask
       ask - how does authentication work in this repo?
       echo summarize this tree | ask

SEE ALSO
       agents/ask/README.md, agents/ask/SYSTEM.md
