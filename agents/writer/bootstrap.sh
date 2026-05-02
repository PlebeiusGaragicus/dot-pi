#!/usr/bin/env bash

# In-situ agent: keep Playwright/browser-control state under the launch cwd (project-local).
mkdir -p "${PWD}/.browser-control"

export BROWSER_CONTROL_STATE_DIR="${PWD}/.browser-control"

B="$HOME/.dot-pi/utilities/browser-runtime/dist/browser-control"
[ -x "$B" ] || B="bun run $HOME/.dot-pi/utilities/browser-runtime/src/cli.ts"
export B

echo "browser bootstrap: state dir: $BROWSER_CONTROL_STATE_DIR"
echo "browser bootstrap: status"
if ! $B status; then
  echo "browser bootstrap: browser-control status failed" >&2
  return 1
fi
