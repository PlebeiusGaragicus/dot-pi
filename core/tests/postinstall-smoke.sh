#!/usr/bin/env bash
set -euo pipefail

export DOT_PI_SKIP_PLAYWRIGHT_INSTALL=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-postinstall-smoke.XXXXXX")"
OVERLAY="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-postinstall-overlay.XXXXXX")"
SEED_OVERLAY="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-postinstall-seed-overlay.XXXXXX")"
EMPTY_SEED_OVERLAY="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-postinstall-empty-seed-overlay.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$OVERLAY" "$SEED_OVERLAY" "$EMPTY_SEED_OVERLAY"' EXIT

fail() {
  echo "postinstall smoke failed: $*" >&2
  exit 1
}

# sha256 of file (Linux: sha256sum, macOS: shasum, else openssl).
dotpi_file_sha256() {
  local f="$1"
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$f" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$f" | awk '{print $1}'
  else
    openssl dgst -sha256 "$f" 2>/dev/null | awk '{print $NF}'
  fi
}

assert_link() {
  local path="$1"
  [ -L "$path" ] || fail "expected symlink: $path"
}

mkdir -p "$FIXTURE"
cp -R "$ROOT/core" "$ROOT/agents" "$ROOT/shared" "$ROOT/dispatch-agent" "$ROOT/dotpi" "$FIXTURE/"

mkdir -p "$OVERLAY/coder/prompts"
cat > "$OVERLAY/settings.json" <<'EOF'
{
  "theme": "user-owned"
}
EOF
cat > "$OVERLAY/coder/prompts/custom.md" <<'EOF'
# Custom Prompt
EOF

DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null
DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null

grep -q '"theme": "user-owned"' "$OVERLAY/settings.json" || fail "existing theme setting was overwritten"
grep -q '"enableInstallTelemetry": false' "$OVERLAY/settings.json" || fail "missing setting was not merged"
settings_after=$(dotpi_file_sha256 "$OVERLAY/settings.json")
DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null
settings_after_second=$(dotpi_file_sha256 "$OVERLAY/settings.json")
[ "$settings_after" = "$settings_after_second" ] || fail "overlay settings.json changed after defaults were merged"

assert_link "$FIXTURE/shared/settings.json"
assert_link "$OVERLAY/auth.json"
assert_link "$OVERLAY/models.json"
assert_link "$FIXTURE/shared/auth.json"
assert_link "$FIXTURE/shared/models.json"
assert_link "$FIXTURE/agents/coder/settings.json"
assert_link "$OVERLAY/coder/bin"
assert_link "$FIXTURE/agents/coder/bin"
assert_link "$FIXTURE/agents/coder/extensions/lib"
assert_link "$FIXTURE/agents/mas/extensions/lib"
assert_link "$FIXTURE/agents/coder/prompts/custom.md"
assert_link "$FIXTURE/core/bin/coder"
[ "$(readlink "$OVERLAY/coder/bin")" = "$HOME/.pi/agent/bin" ] || fail "overlay coder bin does not point to vanilla pi bin"
[ "$(readlink "$FIXTURE/agents/coder/bin")" = "$OVERLAY/coder/bin" ] || fail "agent coder bin does not point to overlay bin"
[ "$(readlink "$OVERLAY/auth.json")" = "$HOME/.pi/agent/auth.json" ] || fail "overlay auth does not point to vanilla pi auth"
[ "$(readlink "$OVERLAY/models.json")" = "$HOME/.pi/agent/models.json" ] || fail "overlay models does not point to vanilla pi models"
[ "$(readlink "$FIXTURE/shared/auth.json")" = "$OVERLAY/auth.json" ] || fail "shared auth does not point to overlay auth"
[ "$(readlink "$FIXTURE/shared/models.json")" = "$OVERLAY/models.json" ] || fail "shared models does not point to overlay models"
[ ! -L "$FIXTURE/core/bin/resume" ] || fail "global resume symlink should not be recreated"

rm -f "$FIXTURE/agents/coder/prompts/custom.md"
DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null
assert_link "$FIXTURE/agents/coder/prompts/custom.md"

DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$SEED_OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null
grep -q '"enableInstallTelemetry": false' "$SEED_OVERLAY/settings.json" || fail "missing enableInstallTelemetry seed"
grep -q '"theme": "synthwave"' "$SEED_OVERLAY/settings.json" || fail "missing theme seed"
grep -q '"collapseChangelog": true' "$SEED_OVERLAY/settings.json" || fail "missing collapseChangelog seed"

cat > "$EMPTY_SEED_OVERLAY/settings.json" <<'EOF'
{}
EOF
DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$EMPTY_SEED_OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null
grep -q '"theme": "synthwave"' "$EMPTY_SEED_OVERLAY/settings.json" || fail "empty settings seed was not upgraded"

echo "postinstall smoke: ok"
