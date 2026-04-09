# Pi Recipes -- Agent Rules

## Project Overview

This is a collection of extensions, skills, prompts, agent personas, themes, and examples for the Pi Coding Agent. It serves as a reference library and boilerplate kit for developer teams using the pi agentic system.

## First Message

If the user did not give you a concrete task, read README.md, then ask what they want to work on:
- Building a new extension? Read `docs/EXTENSION-API.md` and browse `extensions/examples/boilerplate/`
- Creating a new skill? Read `docs/skills.md` and browse `.pi/skills/` for examples
- Setting up agent personas? Browse `.pi/agents/` for patterns
- Running recipes? Check the `justfile`

## Code Quality

- Extensions are TypeScript targeting the Pi extension API (`@mariozechner/pi-coding-agent`, `@mariozechner/pi-tui`)
- No `any` types unless absolutely necessary
- Always use top-level imports, never inline `await import()`
- Follow existing extension patterns in `extensions/examples/boilerplate/` for structure

## Directory Conventions

- `extensions/safety/` -- guardrails, permission gates, path protection
- `extensions/ui/` -- display, chrome, feedback, rendering
- `extensions/workflow/` -- session behavior, tools, productivity
- `extensions/orchestration/` -- multi-agent delegation, pipelines
- `extensions/git/` -- git integration hooks
- `extensions/project-scoped/` -- project-level workflow extensions
- `extensions/providers/` -- custom LLM provider implementations
- `extensions/examples/` -- teaching aids and showcases (not production extensions)
  - `extensions/examples/boilerplate/` -- minimal starting-point templates
  - `extensions/examples/patterns/` -- intermediate API pattern showcases
  - `extensions/examples/demos/` -- fun/showcase demos (games, visual effects)
- `.pi/skills/` -- reusable tool-backed capabilities with SKILL.md + scripts
- `.pi/prompts/` -- prompt templates with YAML frontmatter
- `.pi/agents/` -- agent persona definitions (markdown with system prompts)
- `.pi/themes/` -- theme JSON files (51 color tokens)
- `docs/` -- reference documentation
- `specs/` -- feature specifications
- `scripts/` -- standalone utility scripts
- `examples/sdk/` -- SDK usage examples

## Adding New Content

### New Extension
1. Choose the right category directory
2. Use `extensions/examples/boilerplate/hello.ts` as a minimal starting point
3. Add an entry to the relevant table in README.md
4. Add a justfile recipe if the extension is commonly used standalone

### New Skill
1. Create a directory under `.pi/skills/<name>/`
2. Add a `SKILL.md` with YAML frontmatter (`name`, `description`)1
3. Add supporting scripts in the skill directory
4. Add an entry to the Skills section in README.md

### New Prompt Template
1. Create a `.md` file in `.pi/prompts/`
2. Include YAML frontmatter with `description`
3. Use `$ARGUMENTS` or `$@` for argument substitution

### New Agent Persona
1. Create a `.md` file in `.pi/agents/`
2. Write the system prompt as the file content
3. Reference it from team/chain YAML configs if needed

## Style

- No emojis in code, commits, or documentation
- Keep comments minimal -- only explain non-obvious intent
- Technical prose, direct and concise
- Extension file names use kebab-case (e.g., `my-extension.ts`)

## Commands

- Run recipes: `just <recipe>` or `fu <recipe>` from any directory
- Test a single extension: `pi -e extensions/<category>/<file>.ts`
- Stack extensions: `pi -e ext1.ts -e ext2.ts`

## README Updates

When adding extensions, skills, prompts, or other content, always update the relevant section in README.md to keep the inventory accurate.
