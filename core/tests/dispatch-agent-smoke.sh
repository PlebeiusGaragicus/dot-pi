#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-dispatch-smoke.XXXXXX")"
OVERLAY="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-dispatch-overlay.XXXXXX")"
trap 'rm -rf "$FIXTURE" "$OVERLAY"' EXIT

fail() {
  echo "dispatch smoke failed: $*" >&2
  exit 1
}

assert_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" == *"$needle"* ]] || fail "$label: expected to contain [$needle]; got: $haystack"
}

assert_not_contains() {
  local haystack="$1" needle="$2" label="$3"
  [[ "$haystack" != *"$needle"* ]] || fail "$label: did not expect [$needle]; got: $haystack"
}

run_capture() {
  local label="$1"
  shift
  local output status
  set +e
  output=$(DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" DOTPI_DISPATCH_CAPTURE_PI=1 "$@" < /dev/null 2>&1)
  status=$?
  set -e
  if [ "$status" -ne 0 ] && [[ "$output" != *"PI_CODING_AGENT_DIR="* ]]; then
    fail "$label exited $status: $output"
  fi
  CAPTURE_OUT="$output"
}

run_capture_stdin() {
  local label="$1" stdin="$2"
  shift 2
  local output status
  set +e
  output=$(printf '%s' "$stdin" | DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" DOTPI_DISPATCH_CAPTURE_PI=1 "$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -ne 0 ] && [[ "$output" != *"PI_CODING_AGENT_DIR="* ]]; then
    fail "$label exited $status: $output"
  fi
  CAPTURE_OUT="$output"
}

run_error() {
  local label="$1"
  shift
  local output status
  set +e
  output=$(DOT_PI_DIR="$FIXTURE" DOT_PI_OVERLAY="$OVERLAY" DOTPI_DISPATCH_CAPTURE_PI=1 "$@" < /dev/null 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "$label unexpectedly succeeded: $output"
  CAPTURE_OUT="$output"
}

cwd_session_dir() {
  local encoded
  encoded="${PWD#/}"
  encoded="${encoded//\//-}"
  printf '%s/%s/sessions/--%s--' "$OVERLAY" "$1" "$encoded"
}

mkdir -p "$FIXTURE/core/bin" "$FIXTURE/agents/coder" "$FIXTURE/agents/lm" "$FIXTURE/agents/browser"
ln -s "$ROOT/core" "$FIXTURE/core_src"
ln -s "$FIXTURE/core_src/dispatch" "$FIXTURE/core/dispatch"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/coder"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/lm"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/browser"

# coder: no pi-args (no --model)
touch "$FIXTURE/agents/coder/pi-args"

cat > "$FIXTURE/agents/lm/pi-args" <<'EOF'
--thinking
off
--no-tools
--no-skills
--no-context-files
EOF

cat > "$FIXTURE/agents/browser/pi-args" <<'EOF'
--tools
read,ls,bash
--no-context-files
EOF

run_capture "coder no args" "$FIXTURE/core/bin/coder"
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/coder" "coder no args"
assert_contains "$CAPTURE_OUT" "ARGV" "coder no args"
assert_contains "$CAPTURE_OUT" $'\t--session-dir\t'"$(cwd_session_dir coder)" "coder session dir"
assert_not_contains "$CAPTURE_OUT" $'\t--model' "coder no --model in argv"

run_capture "lm interactive prompt" "$FIXTURE/core/bin/lm" - hi there
assert_contains "$CAPTURE_OUT" $'\t--thinking\toff' "lm interactive prompt"
assert_contains "$CAPTURE_OUT" $'\thi there' "lm interactive prompt"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm interactive prompt"
assert_not_contains "$CAPTURE_OUT" $'\t-p\t' "lm interactive prompt"

run_capture "lm print prompt" "$FIXTURE/core/bin/lm" -p hi
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm print prompt"
assert_contains "$CAPTURE_OUT" $'\t-p\thi' "lm print prompt"

run_capture "lm print verbose prompt" "$FIXTURE/core/bin/lm" -p -v hi
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm print verbose prompt"
assert_contains "$CAPTURE_OUT" $'\t-p\thi' "lm print verbose prompt"

run_capture "browser print overlay session" "$FIXTURE/core/bin/browser" -p status
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/browser" "browser print overlay session"
assert_contains "$CAPTURE_OUT" $'\t--tools\tread,ls,bash' "browser print overlay session"
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser print overlay session"
assert_contains "$CAPTURE_OUT" $'\t--session-dir\t'"$(cwd_session_dir browser)" "browser print overlay session"
assert_contains "$CAPTURE_OUT" $'\t-p\tstatus' "browser print overlay session"

run_error "browser named option removed" "$FIXTURE/core/bin/browser" -n named - prompt text
assert_contains "$CAPTURE_OUT" "was removed with workspace mode" "browser named option removed"

run_error "browser resume removed" "$FIXTURE/core/bin/browser" resume old-workspace
assert_contains "$CAPTURE_OUT" "resume' was removed with workspace mode" "browser resume removed"

# --- Skills do not run launch-time bootstraps ---

# Create an in-situ agent with a skill that has scripts/bootstrap.sh.
# Skill scripts are normal skill assets and must not be sourced at launch.
mkdir -p "$FIXTURE/agents/searcher/skills/test-skill/scripts"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/searcher"

cat > "$FIXTURE/agents/searcher/pi-args" <<'EOF'
--no-context-files
EOF

cat > "$FIXTURE/agents/searcher/skills/test-skill/scripts/bootstrap.sh" <<'EOF'
echo "skill bootstrap should not run"
return 1
EOF

cat > "$FIXTURE/agents/searcher/skills/test-skill/SKILL.md" <<'EOF'
---
name: test-skill
description: Smoke test skill
---
# Test Skill
EOF

cat > "$FIXTURE/agents/searcher/bootstrap.sh" <<'EOF'
export AGENT_BOOTSTRAP_SENTINEL="agent-ran"
echo "agent bootstrap: searcher loaded"
EOF

run_capture "skill bootstrap ignored" "$FIXTURE/core/bin/searcher"
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/searcher" "skill bootstrap ignored agent"
BOOTSTRAP_LOG="$FIXTURE/agents/searcher/sessions/bootstrap.log"
BOOTSTRAP_LOG="$(cwd_session_dir searcher)/bootstrap.log"
[ -f "$BOOTSTRAP_LOG" ] || fail "skill bootstrap ignored: bootstrap.log not created"
LOG_CONTENT=$(cat "$BOOTSTRAP_LOG")
assert_contains "$LOG_CONTENT" "bootstrap start: agent searcher" "skill bootstrap ignored: agent logged"
assert_not_contains "$LOG_CONTENT" "skill test-skill" "skill bootstrap ignored: skill not logged"
assert_not_contains "$LOG_CONTENT" "skill bootstrap should not run" "skill bootstrap ignored: script output absent"

echo "dispatch-agent smoke: ok"
