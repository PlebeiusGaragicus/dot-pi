#!/usr/bin/env bash

WORKSPACE_AGENT=1
export WORKSPACE_AGENT

if [ -z "${WORKSPACE_DIR:-}" ]; then
  echo "deepresearch bootstrap: WORKSPACE_DIR is required" >&2
  return 1
fi

mkdir -p "$WORKSPACE_DIR/sources" "$WORKSPACE_DIR/screenshots" "$WORKSPACE_DIR/sessions"

echo "deepresearch bootstrap: workspace ready at $WORKSPACE_DIR"
echo "deepresearch bootstrap: created sources/, screenshots/, sessions/"
