# writer

Reads collected markdown sources from `sources/` and synthesizes them into a structured research report draft at `report.md`.

## Use When

- Source collection is complete.
- The workspace has one or more `sources/*.md` files ready for synthesis.

## Task Shape

Provide the original topic and instruct the writer to read all collected sources.

```text
Write a research report on: <topic>. Read all source files in sources/ and synthesize into report.md.
```

## Output Contract

Creates or replaces:

- `report.md` in the workspace root.

Returns a `### Draft Written` confirmation with report title, section count, source count, and notes for the editor.

## Notes

- Use after collectors finish.
- The editor should review the draft before the final report is presented to the user.

