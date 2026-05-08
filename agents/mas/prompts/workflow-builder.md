# Workflow Builder

Help the user create, troubleshoot, enhance, or revise a project-local `mas` workflow prompt. Generated or modified workflows must live under the current working directory's `.pi/prompts/` directory unless the user explicitly asks for a different location.

## Goal

Turn a workflow idea, bug report, rough draft, or existing project workflow into a coherent prompt-template file that `mas` can run from the current project. The result should be a durable `.pi/prompts/<workflow-name>.md` artifact, not just advice in chat.

## Required Trajectory

Follow these phases in order. Do not skip the review checkpoint before writing unless the user explicitly supplied a complete approved spec and asked you to write it directly.

### 1. Preflight

- Parse the user request at the end of this prompt for:
  - create vs modify mode
  - desired workflow name or existing workflow path
  - workflow goal, expected user inputs, artifact outputs, quality gates, stop conditions, and known pain points
  - whether the workflow should read local files, edit files, run commands, browse the web, write reports, or ask for user choices
- Project workflow output defaults to `.pi/prompts/<slug>.md`, where `<slug>` is lowercase kebab-case derived from the workflow name.
- If the request does not identify whether to create or modify, or lacks enough intent to design the workflow responsibly, use `questionnaire` before invoking workers.
- If the requested filename already exists and the user did not ask to modify it, use `questionnaire` to choose overwrite, revise existing, pick a new name, or stop.
- After worker delegation begins, do not use `questionnaire` except at the explicit review checkpoints in this workflow.

### 2. Load Workflow Guidance

Before drafting the workflow spec, use your own tools to read:

- `~/.dot-pi/docs/workflow-writing-guide.md`

If the guide is missing or insufficient for the request, also consult only the needed parts of:

- `~/.dot-pi/docs/reference/multi-agent-systems.md`
- `~/.dot-pi/docs/design/top-level-agent-mas.md`
- `~/.dot-pi/agents/mas/prompts/deepresearch.md`
- `~/.dot-pi/agents/mas/prompts/pdf-ocr.md`

Use these references to enforce capability boundaries, artifact handoffs, validation phases, stop conditions, and final user request handling.

### 3. Inspect Existing Project Context

Use your own `ls` / `find` / `grep` / `read` tools, or call `scout` for read-only exploration, to inspect relevant local context:

- `.pi/prompts/` for existing project workflows
- the existing workflow file when modifying
- nearby project docs or artifacts mentioned by the user

If using `scout`, ask it only to locate and summarize local files. Do not ask it to edit, run commands, or browse the web.

For modify mode, read the current workflow before proposing changes. Preserve useful existing behavior unless the user asks to replace it.

### 4. Draft Review Spec

Present a concise workflow spec to the user before writing files. Include:

- workflow name and target path
- create or modify mode
- user input expected in the final user request section
- phases and delegation plan
- worker capability mapping (`ask`, `scout`, `writer`, `coder`, `web`)
- artifact conventions and ownership
- validation and repair passes
- stop conditions and final response shape
- assumptions, risks, and open choices

Then use `questionnaire` to ask whether the user approves the spec, wants revisions, wants to rename the workflow, or wants to cancel. If the user requests revisions, update the spec and ask again. Keep iterating until the user approves or cancels.

Stop if the user cancels. Do not write a workflow from an unapproved spec.

### 5. Prepare Project Prompt Directory

Confirm `.pi/prompts/` exists. If it does not exist, call `coder` once with a tightly scoped task to create only that directory.

The coder task must be equivalent to:

```text
Create the project prompt directory `.pi/prompts/` in the current working directory if it does not already exist.

Constraints:
- Do not create or modify any other files.
- Do not initialize config, install packages, or run unrelated commands.

Reply with the directory path and whether it was created or already existed.
```

If directory creation fails, stop and report the blocker.

### 6. Write Or Revise Workflow

Call `writer` once to create or revise the workflow file. The writer task must include:

```text
You are writing a `mas` workflow prompt template.

Target path: .pi/prompts/<workflow-name>.md
Mode: create new | revise existing

Use the approved spec below and write a coherent markdown workflow prompt.

Requirements:
- Follow dot-pi workflow conventions.
- Make the workflow orchestration policy, not capability grants.
- Include explicit phases, worker delegation contracts, artifact conventions, validation, stop conditions, and final response guidance.
- End with a `## User Request` section that contains the standard user input block. The placeholder line must be the dollar-at token, written as a dollar sign immediately followed by an at sign, and it should appear only in that final block.
- For modify mode, preserve useful existing behavior and improve only what the approved spec requires.
- Do not edit files outside `.pi/prompts/<workflow-name>.md`.
- Return a concise confirmation with the written path, major changes, and any unresolved caveats.

Approved spec:
<paste approved spec>

Existing workflow, if modifying:
<paste relevant existing content or summary>
```

If the workflow needs command execution or generated non-prose assets during writing, stop and explain why the requested workflow is outside `writer`'s scope instead of silently switching workers.

### 7. Validate Written Workflow

After `writer` returns, use your own `read` tool to inspect `.pi/prompts/<workflow-name>.md`.

Validate that it has:

- a clear title and goal
- a required trajectory or equivalent phase structure
- explicit worker delegation matched to structural capabilities
- artifact conventions when files are produced
- stop conditions
- validation or review guidance
- final response guidance
- `## User Request`
- the dollar-at placeholder appearing only in the final user request block

If validation fails, run one repair pass with `writer`, then read the file again. If it still fails, stop with the file path and remaining issues.

If you use `ask` with persona `judge` for an additional semantic check, pass the workflow excerpt and checklist inline. Never ask `ask` to inspect the file path.

## Artifact Conventions

- Project workflows are stored under `.pi/prompts/`.
- Default generated path is `.pi/prompts/<workflow-name>.md`.
- Workflow names should be lowercase kebab-case.
- Do not write bundled prompts under `~/.dot-pi/agents/mas/prompts/` unless the user explicitly requests a dot-pi repo change rather than a project workflow.
- Do not create project-local subagents, skills, or config files unless the user explicitly expands the scope.

## Stop Conditions

- The user cancels at a questionnaire checkpoint.
- The workflow idea is too ambiguous and the user declines to clarify.
- The target file collision cannot be resolved.
- `.pi/prompts/` cannot be created.
- The requested workflow requires structural capabilities not available to the `mas` worker catalog.
- Validation fails after one repair pass.

## Final Response

Keep the final response short. Prefer:

`Workflow written to ./.pi/prompts/<workflow-name>.md. Run it with /<workflow-name> ... from mas in this project.`

If the workflow was modified, mention the path and the most important change. If the workflow stopped early, state the blocker and any partial artifact path.

## User Request

Treat the text below as the user's instructions for creating, troubleshooting, enhancing, or revising a project-local `mas` workflow prompt.

**User prompt:**
`$@`
