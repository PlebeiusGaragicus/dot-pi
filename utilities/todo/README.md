The `todo` utility is a simple shell script for managing todo.jsonl task lists.

## todo file

When `todo` runs, it looks for `todo.jsonl` in the current directory, then each parent directory up to the root. That file is the project or workspace todo list. If none exists, the active file is `~/.todo/todo.jsonl` (the directory is created if needed).

## data format

Each line is one JSON object:

```json
{
    "id": 0,
    "text": "do the dishes",
    "done": false
}
```

`id` is a non-negative integer. New tasks get the next free id: max existing id plus one, starting from `0` when the file is empty.

## usage

```sh
todo                 # prints usage
todo file            # absolute path to active todo.jsonl
todo list            # markdown lines: - [ ] (id) text  /  - [x] (id) text
todo new "task text"
todo edit <id> "replacement text"
todo del <id>
todo done <id>
todo undone <id>
todo version
```

## prerequisites

- `bash`
- `jq`

## install

Create `~/.local/bin` if needed, symlink this repo’s `todo` script there, and ensure that directory is on your `PATH` (many shells include it by default; otherwise add `export PATH="$HOME/.local/bin:$PATH"` to your shell rc).

If this repository lives at `~/.dot-pi`, run:

```sh
mkdir -p ~/.local/bin
ln -sf "$HOME/.dot-pi/utilities/todo/todo" "$HOME/.local/bin/todo"
```

If the repo is elsewhere, replace the first path with the absolute path to `utilities/todo/todo` inside your checkout.

Check:

```sh
command -v todo && todo version
```
