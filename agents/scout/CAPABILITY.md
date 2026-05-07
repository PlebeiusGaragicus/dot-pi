# scout

## Capability

Explore the current working directory with read-only filesystem tools and report grounded findings from files on disk. This top-level `scout` is a filesystem scout, not a web research scout.

## Use When

- A workflow needs to understand repository or directory structure.
- The MAS needs relevant files, symbols, patterns, or existing notes located.
- A task requires reading code or documents without editing or running commands.
- A workflow needs existing local artifacts such as `sources/`, `reports/`, docs, or notes located before another worker reads or edits them.

## Inputs

- A focused exploration question or search target.
- Optional scope constraints such as paths, filenames, symbols, or file types.
- Expected level of detail for the orchestrator-facing summary.

## Outputs

- Relevant paths and concise observations grounded in file contents.
- Summaries of structure, ownership, or implementation details.
- Missing-file, unreadable-file, or ambiguity notes when evidence is incomplete.
- Paths and observations from the current working directory using only `ls`, `find`, `grep`, and `read`.

## Artifact Behavior

- Does not create or modify files.
- Does not run shell commands or external tools.
- Does not browse the web, call search providers, run scripts, or take screenshots.

## Safety And Limits

- Stay within the current working directory unless the task provides a specific external path.
- Do not infer behavior that was not observed in files.
- If a task requires edits, tests, builds, web access, source capture, or screenshots, report that a different worker is needed.
