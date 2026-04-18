# Evals

Serial evaluation runner for testing agent teams against scripted prompts.

## Usage

```bash
./evals/run-eval.sh [--with-retro] <team> <prompts-file>
```

Both positional arguments are required. Reads one prompt per line from the prompts file, runs each through `pi-<team> -p "..."` in non-interactive mode, and logs results to a JSONL manifest.

Each prompt gets its own workspace (for workspace teams) and output file. Results are organized by team and eval name (derived from the prompts filename).

## Options

- `--with-retro` -- Run retrospective analysis on each workspace after the prompt completes.
  Retro output is saved to `prompt-N-retro.txt` alongside prompt output.

## Examples

```bash
# Quick smoke test (4 prompts)
./evals/run-eval.sh deepresearch evals/deepresearch-short.txt

# Comprehensive suite
./evals/run-eval.sh deepresearch evals/deepresearch-long.txt

# With retro analysis after each prompt
./evals/run-eval.sh --with-retro deepresearch evals/deepresearch-short.txt
```

## Prompts File Format

One prompt per line. Blank lines and lines starting with `#` are skipped.

```
Lookup how many voters are registered in the state of Oregon.
Provide an update on the Iran war with a focus on maritime traffic.
# This line is a comment and will be skipped.
```

## Output Structure

The eval name is derived from the prompts filename (without `.txt` extension):

```
evals/results/<team>/<eval-name>/<timestamp>/
├── prompt-1-output.txt     # Stdout/stderr from pi for prompt 1
├── prompt-1-retro.txt      # Retro output for prompt 1 (when --with-retro)
├── prompt-2-output.txt     # Stdout/stderr from pi for prompt 2
├── prompt-2-retro.txt      # Retro output for prompt 2 (when --with-retro)
└── manifest.jsonl          # One JSON object per prompt with metadata
```

For example, `./evals/run-eval.sh deepresearch evals/deepresearch-short.txt` writes to `evals/results/deepresearch/deepresearch-short/<timestamp>/`.

### Manifest Fields

| Field | Description |
|-------|-------------|
| `prompt_num` | 1-indexed prompt number |
| `prompt` | The prompt text |
| `workspace` | Path to the workspace directory (for workspace teams) |
| `exit_code` | pi's exit code (0 = success) |
| `duration_seconds` | Wall-clock runtime |

## Requirements

- `jq` must be on PATH
- `bash_aliases` must be sourceable (the script sources it to get team aliases)
