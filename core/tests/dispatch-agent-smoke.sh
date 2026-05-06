#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
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

run_capture_stdin() {
  local label="$1" stdin="$2"
  shift 2
  local output status
  set +e
  output=$(printf '%s' "$stdin" | DOT_PI_DIR="$FIXTURE" DOTPI_DISPATCH_CAPTURE_PI=1 "$@" 2>&1)
  status=$?
  set -e
  if [ "$status" -ne 0 ] && [[ "$output" != *"PI_CODING_AGENT_DIR="* ]]; then
    fail "$label exited $status: $output"
  fi
  CAPTURE_OUT="$output"
}

mkdir -p "$FIXTURE/core/bin" "$FIXTURE/agents/coder" "$FIXTURE/agents/lm" \
  "$FIXTURE/agents/browser" "$FIXTURE/agents/browser/workspaces/2026-04-29-000000--prefix/sessions"
ln -s "$ROOT/core" "$FIXTURE/core_src"
ln -s "$FIXTURE/core_src/dispatch" "$FIXTURE/core/dispatch"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/coder"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/lm"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/browser"

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

run_capture "coder no args" "$FIXTURE/core/bin/coder"
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/coder" "coder no args"
assert_contains "$CAPTURE_OUT" "ARGV" "coder no args"
assert_not_contains "$CAPTURE_OUT" $'\t--model' "coder model fall-through"

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

run_capture "browser print workspace" "$FIXTURE/core/bin/browser" -p status
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/browser" "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t--tools\tread,ls,bash' "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t--session-dir\t' "browser print workspace"
assert_contains "$CAPTURE_OUT" $'\t-p\tstatus' "browser print workspace"

run_capture "browser named interactive workspace" "$FIXTURE/core/bin/browser" -n named - prompt text
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/browser" "browser named interactive workspace"
assert_contains "$CAPTURE_OUT" $'\t--session-dir\t' "browser named interactive workspace"
assert_contains "$CAPTURE_OUT" $'\tprompt text' "browser named interactive workspace"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser named interactive workspace"
assert_not_contains "$CAPTURE_OUT" $'\t-p\t' "browser named interactive workspace"

run_capture "browser exact resume prompt" "$FIXTURE/core/bin/browser" resume 2026-04-29-000000--prefix - continue here
assert_contains "$CAPTURE_OUT" "Resuming: $FIXTURE/agents/browser/workspaces/2026-04-29-000000--prefix" "browser resume prompt"
assert_contains "$CAPTURE_OUT" $'\t--continue' "browser resume prompt"
assert_contains "$CAPTURE_OUT" $'\tcontinue here' "browser resume prompt"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser resume prompt"

# Clean up workspace dirs created by earlier tests so the picker only has the fixture entry
find "$FIXTURE/agents/browser/workspaces" -mindepth 1 -maxdepth 1 -type d ! -name '2026-04-29-000000--prefix' -exec rm -rf {} +
run_capture_stdin "browser picker resume prompt" $'1\n' "$FIXTURE/core/bin/browser" resume - continue from picker
assert_contains "$CAPTURE_OUT" "Workspaces for browser:" "browser picker resume prompt"
assert_contains "$CAPTURE_OUT" "Resuming: $FIXTURE/agents/browser/workspaces/2026-04-29-000000--prefix" "browser picker resume prompt"
assert_contains "$CAPTURE_OUT" $'\tcontinue from picker' "browser picker resume prompt"

# --- Skills do not run launch-time bootstraps ---

# Create an in-situ agent with a skill that has scripts/bootstrap.sh.
# Skill scripts are normal skill assets and must not be sourced at launch.
mkdir -p "$FIXTURE/agents/searcher/skills/test-skill/scripts"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/core/bin/searcher"

cat > "$FIXTURE/agents/searcher/pi-args" <<'EOF'
--model
$DEFAULT_FAST_MODEL
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
[ -f "$BOOTSTRAP_LOG" ] || fail "skill bootstrap ignored: bootstrap.log not created"
LOG_CONTENT=$(cat "$BOOTSTRAP_LOG")
assert_contains "$LOG_CONTENT" "bootstrap start: agent searcher" "skill bootstrap ignored: agent logged"
assert_not_contains "$LOG_CONTENT" "skill test-skill" "skill bootstrap ignored: skill not logged"
assert_not_contains "$LOG_CONTENT" "skill bootstrap should not run" "skill bootstrap ignored: script output absent"

echo "dispatch-agent smoke: ok"
