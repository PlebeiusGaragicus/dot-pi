# coder

## Capability

Perform coding work in the current working directory with filesystem editing tools and shell command execution.

## Use When

- A workflow needs code changes, tests, builds, debugging, or command-line inspection.
- The MAS needs implementation work that exceeds read-only exploration or prose editing.
- A task requires repository context and may benefit from local coding guidance files.
- A workflow requires command execution that is not web research, source capture, or prose-only editing.

## Inputs

- A concrete implementation, debugging, or verification task.
- Relevant paths, expected behavior, and testing expectations.
- Any constraints on commands, files, or scope.

## Outputs

- Code or configuration changes when explicitly requested.
- Test, build, or command results relevant to the delegated task.
- Concise operational notes for the orchestrator, including changed paths and blockers.
- Command output summaries, test results, or implementation notes when those are part of the delegated coding task.

## Artifact Behavior

- May create or modify files when the task explicitly requests implementation or repair.
- May run shell commands for inspection, tests, builds, and debugging.
- Should mention important changed paths and verification results in the final worker reply.
- Uses pi's default coding behavior plus `APPEND_SYSTEM.md`; a missing local `SYSTEM.md` is intentional.

## Safety And Limits

- Keep changes tightly scoped to the delegated task.
- Do not perform destructive commands unless explicitly instructed.
- This worker intentionally keeps context-file behavior enabled in v1, so it may load project guidance such as `AGENTS.md`.
- Do not ask the end user questions in worker mode; return a concise blocker or assumption for the orchestrator.
- Do not use `coder` as a substitute for `web` source collection, `writer` prose review, or `ask` semantic judgement unless command execution or code changes are actually required.
