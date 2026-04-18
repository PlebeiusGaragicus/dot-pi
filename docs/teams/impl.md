# Impl Team

Code implementation and review.

## Agents

### worker

| Field | Value |
|-------|-------|
| Tools | all defaults |

General-purpose agent with full capabilities. Works autonomously in an isolated context to complete delegated tasks. Reports what was done, which files changed, and any notes for followup.

### reviewer

| Field | Value |
|-------|-------|
| Tools | read, grep, find, ls, bash |

Senior code reviewer. Analyzes code for quality, security, and maintainability. Uses bash only for read-only git commands (`git diff`, `git log`). Reports critical issues, warnings, and suggestions with exact file paths and line numbers.

## Prompts

### `/implement-and-review`

Iterative implementation workflow:

1. **worker** implements the requested changes
2. **reviewer** reviews the implementation
3. **worker** applies the review feedback

```
/implement-and-review add input validation to all API endpoints
```

## Usage

```bash
# Via p
p impl "Fix the login bug in auth.ts"

# With the workflow prompt
p impl
> /implement-and-review refactor the database connection pool
```
