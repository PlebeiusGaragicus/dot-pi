ASK(1)                            dot-pi                            ASK(1)

NAME
       ask — read-only explain agent for the current directory (in-situ)

SYNOPSIS
       ask help | usage | -h | --help

       ask
       ask - prompt words...
       ask -p prompt words...
       ask -p -v prompt words...

DESCRIPTION
       ask launches pi configured for inspection of the current tree.  It
       should not modify files; tools and SYSTEM.md enforce read-only use.

OPTIONS
       -p, --print
              Non-interactive run.  Print the final assistant reply and exit.
              Accepts prompt words or piped stdin.

       -v, --verbose
              With -p/--print, also show turn/tool progress on stderr.

COMMANDS
       help, usage, -h, --help
              Show this page on standard output.

EXAMPLES
       ask
       ask - how does authentication work in this repo?
       ask -p how does authentication work in this repo?
       ask -p -v summarize this tree
       echo summarize this tree | ask -p

SEE ALSO
       agents/ask/README.md, agents/ask/SYSTEM.md
