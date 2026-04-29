#!/usr/bin/env bash

WORKSPACE_AGENT=1
export WORKSPACE_AGENT

if [ -z "${WORKSPACE_DIR:-}" ]; then
  echo "browser bootstrap: WORKSPACE_DIR is required" >&2
  return 1
fi

mkdir -p "$WORKSPACE_DIR/.browser-control" "$WORKSPACE_DIR/sessions"

export BROWSER_CONTROL_STATE_DIR="$WORKSPACE_DIR/.browser-control"

B="$HOME/.dot-pi/utilities/browser-runtime/dist/browser-control"
[ -x "$B" ] || B="bun run $HOME/.dot-pi/utilities/browser-runtime/src/cli.ts"
export B

echo "browser bootstrap: state dir: $BROWSER_CONTROL_STATE_DIR"
echo "browser bootstrap: status"
if ! $B status; then
  echo "browser bootstrap: browser-control status failed" >&2
  return 1
fi
