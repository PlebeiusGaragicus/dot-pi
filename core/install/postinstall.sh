#!/usr/bin/env bash
set -euo pipefail

DOT_PI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOT_PI_DIR

# shellcheck source=core/install/lib.sh
source "$DOT_PI_DIR/core/install/lib.sh"

DOT_PI_OVERLAY="${DOT_PI_OVERLAY:-$HOME/.pi/dot-pi}"
export DOT_PI_OVERLAY

dotpi_relink "$DOT_PI_DIR" "$DOT_PI_OVERLAY"
dotpi_install_browser_runtime_playwright
dotpi_postinstall_path_hint

printf "\nLM Studio users: run this script to populate your pi's models.json\n"
printf '  "%s/core/scripts/lmstudio-models" > ~/.pi/agent/models.json\n' "$DOT_PI_DIR"
printf '\n'
printf '  Warning: using > replaces the entire file; run without a redirect to print JSON only.\n'
printf '  Merge instead if you keep other providers (docs/install.md#lm-studio-model-catalog).\n'
