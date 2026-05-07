# ask

## Capability

Provide chat-only reasoning, semantic evaluation, classification, critique, and concise judgement without using tools or reading files.

## Use When

- A workflow needs an independent reasoning pass over text already supplied by the orchestrator.
- The MAS needs classification, ranking, critique, or a PASS/FAIL quality gate.
- A task should not inspect the filesystem, browse the web, or make changes.

## Inputs

- A self-contained question, excerpt, artifact summary, or evaluation brief.
- Optional persona name such as `judge` or `classifier` for repeated evaluation patterns.
- Explicit criteria, categories, or success conditions.
- For `judge` or `classifier` personas, the orchestrator must inline the text to evaluate. File paths, URLs, and artifact names are not evidence unless their contents are included in the task.

## Outputs

- Concise reasoning or judgement for the orchestrator.
- PASS/FAIL, category labels, rankings, or short critique when requested.
- Uncertainty or blocker notes when the input is insufficient.

## Artifact Behavior

- Does not read, create, or modify files.
- Relies only on context included in the delegated task.
- Cannot inspect `reports/report.md`, `sources/*.md`, screenshots, URLs, commands, or runtime state.

## Safety And Limits

- Do not claim to have inspected files, URLs, tools, or runtime state.
- If the task requires external evidence or file inspection, report that a different worker is needed.
- Do not accept path-only validation tasks. A valid evaluation task includes the artifact text or a concise excerpt plus the rubric.
- Reply to the orchestrator only; avoid user-facing preamble and closing text in worker mode.
