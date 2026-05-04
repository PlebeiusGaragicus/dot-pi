#!/usr/bin/env bash
# shellcheck disable=SC2034,SC2296
# dot-pi environment — sourced from ~/.zshrc or ~/.bashrc.
# Sets env vars only; no functions, no aliases.
# Agent commands live in core/bin/ on PATH (see dispatch-agent).

DOT_PI_INSTALLED=1
PI_TELEMETRY=0

if [ -n "${ZSH_VERSION:-}" ]; then
    DOT_PI_DIR="${DOT_PI_DIR:-$(cd "$(dirname "${(%):-%x}")" && pwd)}"
else
    DOT_PI_DIR="${DOT_PI_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)}"
fi

