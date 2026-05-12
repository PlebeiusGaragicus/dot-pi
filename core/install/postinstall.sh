#!/usr/bin/env bash
set -euo pipefail

DOT_PI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
export DOT_PI_DIR

# shellcheck source=core/install/lib.sh
source "$DOT_PI_DIR/core/install/lib.sh"

DOT_PI_OVERLAY="${DOT_PI_OVERLAY:-$HOME/.pi/dot-pi}"
export DOT_PI_OVERLAY

dotpi_relink "$DOT_PI_DIR" "$DOT_PI_OVERLAY"
dotpi_postinstall_path_hint
