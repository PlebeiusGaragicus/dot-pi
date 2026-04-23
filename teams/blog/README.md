# blog

Blog content production team for technical writing. Runs in a workspace (fresh dated directory per session).

## Usage

```
blog "write a post about X"       # new workspace session
blog --list                        # list past workspaces
blog --resume                      # resume latest workspace
blog --resume 2025-04              # resume by date prefix
```

## Retrospective

```
run-retro blog                     # analyze latest workspace
run-retro blog --pick              # choose a workspace interactively
```
