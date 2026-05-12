#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-path-rc-smoke.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
_saved_PATH="${PATH:-}"

fail() {
  echo "path-rc smoke failed: $*" >&2
  exit 1
}

export HOME="$TMP"
export DOT_PI_DIR="$ROOT"
export SHELL=/bin/bash

# shellcheck source=core/install/lib.sh
source "$ROOT/core/install/lib.sh"

rc="$HOME/.bashrc"
: >"$rc"

dotpi_append_path_block "$rc" 0 || fail "first append"
grep -qF 'BEGIN_DOT_PI_PATH' "$rc" || fail "missing begin marker"
grep -qF 'END_DOT_PI_PATH' "$rc" || fail "missing end marker"
grep -qF "$ROOT/core/bin" "$rc" || fail "missing core/bin in export"

begins=$(grep -cF 'BEGIN_DOT_PI_PATH' "$rc" || true)
[ "$begins" -eq 1 ] || fail "expected exactly one block after first append, got $begins"

dotpi_append_path_block "$rc" 0 || fail "second append (refresh)"
begins=$(grep -cF 'BEGIN_DOT_PI_PATH' "$rc" || true)
[ "$begins" -eq 1 ] || fail "expected exactly one block after refresh, got $begins"

PATH="$ROOT/core/bin:${PATH:-}"
dotpi_core_bin_on_path || fail "core bin should be detected on PATH"

mkdir -p "$TMP/emptybin"
PATH="$TMP/emptybin"
export PATH
dotpi_core_bin_on_path && fail "should not detect when probe not on PATH"

export PATH="$ROOT/core/bin"
dotpi_core_bin_on_path || fail "detect with only fixture bin on PATH"

export PATH="$_saved_PATH"

# Non-writable rc → stderr should mention chown (pre-flight, no sudo)
perm_rc="$HOME/.zshrc-perm-smoke"
: >"$perm_rc"
chmod a-w "$perm_rc" 2>/dev/null || true
if dotpi_append_path_block "$perm_rc" 0 2>"$TMP/perm.err"; then
  chmod u+w "$perm_rc" 2>/dev/null || true
  fail "append to read-only rc should fail"
fi
grep -q 'chown' "$TMP/perm.err" || fail "permission error should suggest chown"
chmod u+w "$perm_rc" 2>/dev/null || true
rm -f "$perm_rc" "$TMP/perm.err"

echo "path-rc smoke: ok"
