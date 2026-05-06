#!/usr/bin/env bash

# In-situ agent: keep Playwright/browser-control state under the launch cwd (project-local).
mkdir -p "${PWD}/.browser-control"

echo "browser bootstrap: state dir: ${PWD}/.browser-control"
echo "browser bootstrap: status"
if ! $B status; then
  echo "browser bootstrap: browser-control status failed" >&2
  return 1
fi
