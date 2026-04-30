#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE="$(mktemp -d "${TMPDIR:-/tmp}/dotpi-dispatch-smoke.XXXXXX")"
trap 'rm -rf "$FIXTURE"' EXIT

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
  output=$(DOT_PI_DIR="$FIXTURE" DOTPI_DISPATCH_CAPTURE_PI=1 "$@" < /dev/null 2>&1)
  status=$?
  set -e
  if [ "$status" -ne 0 ] && [[ "$output" != *"PI_CODING_AGENT_DIR="* ]]; then
    fail "$label exited $status: $output"
  fi
  CAPTURE_OUT="$output"
}

mkdir -p "$FIXTURE/bin" "$FIXTURE/agents/coder" "$FIXTURE/agents/lm" \
  "$FIXTURE/agents/browser" "$FIXTURE/workspaces/browser/2026-04-29-000000--prefix/sessions"
ln -s "$ROOT/lib" "$FIXTURE/lib"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/coder"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/lm"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/browser"

cat > "$FIXTURE/model-defaults" <<'EOF'
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
EOF

cat > "$FIXTURE/agents/coder/pi-args" <<'EOF'
--model
$DEFAULT_AGENTIC_MODEL
EOF

cat > "$FIXTURE/agents/lm/pi-args" <<'EOF'
--model
$DEFAULT_FAST_MODEL
--thinking
off
--no-tools
--no-skills
--no-context-files
EOF

cat > "$FIXTURE/agents/browser/pi-args" <<'EOF'
--model
$DEFAULT_FAST_MODEL
--tools
read,ls,bash
--no-context-files
EOF

cat > "$FIXTURE/agents/browser/bootstrap.sh" <<'EOF'
WORKSPACE_AGENT=1
export WORKSPACE_AGENT
mkdir -p "$WORKSPACE_DIR/sessions"
EOF

run_capture "coder no args" "$FIXTURE/bin/coder"
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/coder" "coder no args"
assert_contains "$CAPTURE_OUT" "ARGV" "coder no args"
assert_not_contains "$CAPTURE_OUT" $'\t--model' "coder model fall-through"

run_capture "lm interactive prompt" "$FIXTURE/bin/lm" - hi there
assert_contains "$CAPTURE_OUT" $'\t--thinking\toff' "lm interactive prompt"
assert_contains "$CAPTURE_OUT" $'\thi there' "lm interactive prompt"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm interactive prompt"
assert_not_contains "$CAPTURE_OUT" $'\t-p\t' "lm interactive prompt"

run_capture "lm print prompt" "$FIXTURE/bin/lm" -p hi
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm print prompt"
assert_contains "$CAPTURE_OUT" $'\t-p\thi' "lm print prompt"

run_capture "lm print verbose prompt" "$FIXTURE/bin/lm" -p -v hi
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm print verbose prompt"
assert_contains "$CAPTURE_OUT" $'\t-p\thi' "lm print verbose prompt"

run_capture "lm batch compatibility" "$FIXTURE/bin/lm" --batch hi
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm batch compatibility"
assert_contains "$CAPTURE_OUT" $'\t-p\thi' "lm batch compatibility"

run_capture "browser print workspace" "$FIXTURE/bin/browser" -p status
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/browser" "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t--tools\tread,ls,bash' "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t--session-dir\t' "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t-p\tstatus' "browser print workspace"

run_capture "browser named interactive workspace" "$FIXTURE/bin/browser" -n named - prompt text
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/browser" "browser named interactive workspace"
assert_contains "$CAPTURE_OUT" $'\t--session-dir\t' "browser named interactive workspace"
assert_contains "$CAPTURE_OUT" $'\tprompt text' "browser named interactive workspace"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser named interactive workspace"
assert_not_contains "$CAPTURE_OUT" $'\t-p\t' "browser named interactive workspace"

run_capture "browser resume prompt" "$FIXTURE/bin/browser" resume prefix - continue here
assert_contains "$CAPTURE_OUT" "Resuming: $FIXTURE/workspaces/browser/2026-04-29-000000--prefix" "browser resume prompt"
assert_contains "$CAPTURE_OUT" $'\t--continue' "browser resume prompt"
assert_contains "$CAPTURE_OUT" $'\tcontinue here' "browser resume prompt"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser resume prompt"

echo "dispatch-agent smoke: ok"
