#!/usr/bin/env bash
# Postinstall-style relink: clone-local symlinks and overlay wiring.
# Does not merge settings or mutate user-owned overlay files.

# shellcheck source=core/install/lib.sh
source "$DOT_PI_DIR/core/install/lib.sh"

DOT_PI_OVERLAY="${DOT_PI_OVERLAY:-$HOME/.pi/dot-pi}"
export DOT_PI_OVERLAY

dotpi_relink "$DOT_PI_DIR" "$DOT_PI_OVERLAY"
