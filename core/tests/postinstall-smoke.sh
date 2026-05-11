#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-postinstall-smoke.XXXXXX")"
OVERLAY="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-postinstall-overlay.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$OVERLAY"' EXIT

fail() {
  echo "postinstall smoke failed: $*" >&2
  exit 1
}

assert_link() {
  local path="$1"
  [ -L "$path" ] || fail "expected symlink: $path"
}

mkdir -p "$FIXTURE"
cp -R "$ROOT/core" "$ROOT/agents" "$ROOT/shared" "$ROOT/dispatch-agent" "$ROOT/dotpi" "$FIXTURE/"
if [ -d "$ROOT/subagents" ]; then
  cp -R "$ROOT/subagents" "$FIXTURE/"
else
  mkdir -p "$FIXTURE/subagents"
fi

mkdir -p "$OVERLAY/coder/prompts"
cat > "$OVERLAY/settings.json" <<'EOF'
{
  "theme": "user-owned"
}
EOF
settings_before=$(shasum -a 256 "$OVERLAY/settings.json" | awk '{print $1}')
cat > "$OVERLAY/coder/prompts/custom.md" <<'EOF'
# Custom Prompt
EOF

DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null
DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null

settings_after=$(shasum -a 256 "$OVERLAY/settings.json" | awk '{print $1}')
[ "$settings_before" = "$settings_after" ] || fail "overlay settings.json changed across relinks"

assert_link "$FIXTURE/shared/settings.json"
assert_link "$FIXTURE/agents/coder/settings.json"
assert_link "$FIXTURE/agents/coder/extensions/lib"
assert_link "$FIXTURE/agents/mas/extensions/lib"
assert_link "$FIXTURE/agents/coder/prompts/custom.md"
assert_link "$FIXTURE/core/bin/coder"
[ ! -L "$FIXTURE/core/bin/resume" ] || fail "global resume symlink should not be recreated"

rm -f "$FIXTURE/agents/coder/prompts/custom.md"
DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" bash "$FIXTURE/core/install/postinstall.sh" >/dev/null
assert_link "$FIXTURE/agents/coder/prompts/custom.md"

echo "postinstall smoke: ok"
