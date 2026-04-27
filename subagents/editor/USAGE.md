# editor

Reviews `report.md` against collected source files, corrects accuracy and structure issues, and saves the final polished report.

## Use When

- The writer has produced a draft `report.md`.
- The report needs final validation against `sources/` and `screenshots/`.

## Task Shape

Ask the editor to review the draft against all workspace sources.

```text
Review report.md against source files in sources/. Produce final polished report at report.md.
```

## Output Contract

Creates or replaces:

- `report.md` in the workspace root.

Returns a `### Editorial Review` confirmation with changes made, source coverage, and a quality assessment.

## Notes

- Use as the final subagent step before presenting results.
- After the editor finishes, the orchestrator should read `report.md` and present it to the user.

