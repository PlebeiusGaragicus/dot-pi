#!/usr/bin/env bash
# Skill bootstrap for browser-control. Sourced by dispatch-agent before pi starts.

if [ -z "${BROWSER_CONTROL_STATE_DIR:-}" ]; then
  if [ -n "${WORKSPACE_DIR:-}" ]; then
    export BROWSER_CONTROL_STATE_DIR="$WORKSPACE_DIR/.browser-control"
  else
    export BROWSER_CONTROL_STATE_DIR="${PWD}/.browser-control"
  fi
fi
mkdir -p "$BROWSER_CONTROL_STATE_DIR"

if [ -z "${B:-}" ]; then
  _browser_control_bin="$HOME/.dot-pi/core/utilities/browser-runtime/dist/browser-control"
  if [ -x "$_browser_control_bin" ]; then
    export B="$_browser_control_bin"
  else
    export B="bun run $HOME/.dot-pi/core/utilities/browser-runtime/src/cli.ts"
  fi
  unset _browser_control_bin
fi
