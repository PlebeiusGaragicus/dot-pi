#!/usr/bin/env bash

WORKSPACE_AGENT=1
export WORKSPACE_AGENT

if [ -z "${WORKSPACE_DIR:-}" ]; then
  echo "reader bootstrap: WORKSPACE_DIR is required" >&2
  return 1
fi

mkdir -p "$WORKSPACE_DIR/pages" "$WORKSPACE_DIR/sessions"

echo "reader bootstrap: workspace ready at $WORKSPACE_DIR"
echo "reader bootstrap: created pages/, sessions/"
