# deepresearch

Deep research MAS — search, collect, synthesize, report. Each run gets its own workspace directory.

## Usage

```
deepresearch - survey on topic X             # new prompt run
deepresearch --batch - survey on topic X     # one-shot prompt run
deepresearch -n project-name - survey topic  # named workspace prompt run
deepresearch ls                              # list past workspaces
deepresearch resume                          # resume latest workspace
deepresearch resume project-name             # resume matching workspace
resume                             # choose from recent workspaces
```

## Retrospective

```
run-retro deepresearch             # analyze latest workspace
run-retro deepresearch --pick      # choose a workspace interactively
```
