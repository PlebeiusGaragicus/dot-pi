The 'todo' utility is a simple shell script for managing todo.json task lists

## todo file

when todo is invoked a todo.jsonl file is searched for in the present directory and every parent directory as we walk up the path until one is found.  These would be considered project or workspace specific todo files.  If none is found a system-wide todo file should be created at ~/.todo/todo.jsonl

## data format

Each todo item has a simple format:

```json
{
    "id": "td_2343",
    "text": "do the dishes",
    "finished": false
}
```

id's are prepended with "td_" and have a 4 digit number starting at 0001.

## usage

Here are some commands it supports:

```sh

todo list
todo new "item that needs to be done"
todo edit <id>
todo delete <id>
todo finish <id>
todo unfinish <id>
```

## installation

This utility is meant to be symlink'd into PATH so that any user or bot can call it to manage todo items.