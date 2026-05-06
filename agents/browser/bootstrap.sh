#!/usr/bin/env bash

WORKSPACE_AGENT=1
export WORKSPACE_AGENT

if [ -z "${WORKSPACE_DIR:-}" ]; then
  echo "browser bootstrap: WORKSPACE_DIR is required" >&2
  return 1
fi

mkdir -p "$WORKSPACE_DIR/.browser-control" "$WORKSPACE_DIR/sessions"

echo "browser bootstrap: state dir: $WORKSPACE_DIR/.browser-control"
echo "browser bootstrap: status"
if ! $B status; then
  echo "browser bootstrap: browser-control status failed" >&2
  return 1
fi
