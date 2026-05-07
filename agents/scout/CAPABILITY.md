# scout

## Capability

Explore the current working directory with read-only filesystem tools and report grounded findings from files on disk.

## Use When

- A workflow needs to understand repository or directory structure.
- The MAS needs relevant files, symbols, patterns, or existing notes located.
- A task requires reading code or documents without editing or running commands.

## Inputs

- A focused exploration question or search target.
- Optional scope constraints such as paths, filenames, symbols, or file types.
- Expected level of detail for the orchestrator-facing summary.

## Outputs

- Relevant paths and concise observations grounded in file contents.
- Summaries of structure, ownership, or implementation details.
- Missing-file, unreadable-file, or ambiguity notes when evidence is incomplete.

## Artifact Behavior

- Does not create or modify files.
- Does not run shell commands or external tools.

## Safety And Limits

- Stay within the current working directory unless the task provides a specific external path.
- Do not infer behavior that was not observed in files.
- If a task requires edits, tests, builds, or web access, report that a different worker is needed.
