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

run_capture "browser exact resume prompt" "$FIXTURE/bin/browser" resume 2026-04-29-000000--prefix - continue here
assert_contains "$CAPTURE_OUT" "Resuming: $FIXTURE/workspaces/browser/2026-04-29-000000--prefix" "browser resume prompt"
assert_contains "$CAPTURE_OUT" $'\t--continue' "browser resume prompt"
assert_contains "$CAPTURE_OUT" $'\tcontinue here' "browser resume prompt"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "browser resume prompt"

# Clean up workspace dirs created by earlier tests so the picker only has the fixture entry
find "$FIXTURE/workspaces/browser" -mindepth 1 -maxdepth 1 -type d ! -name '2026-04-29-000000--prefix' -exec rm -rf {} +
run_capture_stdin "browser picker resume prompt" $'1\n' "$FIXTURE/bin/browser" resume - continue from picker
assert_contains "$CAPTURE_OUT" "Workspaces for browser:" "browser picker resume prompt"
assert_contains "$CAPTURE_OUT" "Resuming: $FIXTURE/workspaces/browser/2026-04-29-000000--prefix" "browser picker resume prompt"
assert_contains "$CAPTURE_OUT" $'\tcontinue from picker' "browser picker resume prompt"

# --- Skill bootstrap tests ---

# Create an in-situ agent with a skill that has scripts/bootstrap.sh
mkdir -p "$FIXTURE/agents/searcher/skills/test-skill/scripts"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/searcher"

cat > "$FIXTURE/agents/searcher/pi-args" <<'EOF'
--model
$DEFAULT_FAST_MODEL
--no-context-files
EOF

cat > "$FIXTURE/agents/searcher/skills/test-skill/scripts/bootstrap.sh" <<'EOF'
export SKILL_BOOTSTRAP_SENTINEL="test-skill-ran"
echo "skill bootstrap: test-skill loaded"
EOF

cat > "$FIXTURE/agents/searcher/skills/test-skill/SKILL.md" <<'EOF'
---
name: test-skill
description: Smoke test skill
---
# Test Skill
EOF

run_capture "skill bootstrap runs" "$FIXTURE/bin/searcher"
assert_contains "$CAPTURE_OUT" "PI_CODING_AGENT_DIR=$FIXTURE/agents/searcher" "skill bootstrap agent"
# Check bootstrap log recorded the skill
BOOTSTRAP_LOG="$FIXTURE/agents/searcher/sessions/bootstrap.log"
[ -f "$BOOTSTRAP_LOG" ] || fail "skill bootstrap: bootstrap.log not created"
LOG_CONTENT=$(cat "$BOOTSTRAP_LOG")
assert_contains "$LOG_CONTENT" "bootstrap start: skill test-skill" "skill bootstrap log start"
assert_contains "$LOG_CONTENT" "bootstrap end: skill test-skill status=0" "skill bootstrap log end"
assert_contains "$LOG_CONTENT" "skill bootstrap: test-skill loaded" "skill bootstrap output"

# Skill bootstrap + agent bootstrap: agent runs first, skill second
cat > "$FIXTURE/agents/searcher/bootstrap.sh" <<'EOF'
export AGENT_BOOTSTRAP_SENTINEL="agent-ran"
echo "agent bootstrap: searcher loaded"
EOF

run_capture "agent+skill bootstrap order" "$FIXTURE/bin/searcher"
BOOTSTRAP_LOG="$FIXTURE/agents/searcher/sessions/bootstrap.log"
LOG_CONTENT=$(cat "$BOOTSTRAP_LOG")
assert_contains "$LOG_CONTENT" "bootstrap start: agent searcher" "agent+skill: agent logged"
assert_contains "$LOG_CONTENT" "bootstrap start: skill test-skill" "agent+skill: skill logged"

# Multiple skills sorted by name
mkdir -p "$FIXTURE/agents/searcher/skills/alpha-skill/scripts"
cat > "$FIXTURE/agents/searcher/skills/alpha-skill/scripts/bootstrap.sh" <<'EOF'
echo "skill bootstrap: alpha loaded"
EOF

mkdir -p "$FIXTURE/agents/searcher/skills/zeta-skill/scripts"
cat > "$FIXTURE/agents/searcher/skills/zeta-skill/scripts/bootstrap.sh" <<'EOF'
echo "skill bootstrap: zeta loaded"
EOF

run_capture "multi-skill bootstrap order" "$FIXTURE/bin/searcher"
BOOTSTRAP_LOG="$FIXTURE/agents/searcher/sessions/bootstrap.log"
LOG_CONTENT=$(cat "$BOOTSTRAP_LOG")
# alpha before test-skill before zeta (sorted)
alpha_pos=$(printf '%s' "$LOG_CONTENT" | grep -n "skill alpha-skill" | head -1 | cut -d: -f1)
test_pos=$(printf '%s' "$LOG_CONTENT" | grep -n "skill test-skill" | head -1 | cut -d: -f1)
zeta_pos=$(printf '%s' "$LOG_CONTENT" | grep -n "skill zeta-skill" | head -1 | cut -d: -f1)
[ "$alpha_pos" -lt "$test_pos" ] || fail "multi-skill order: alpha should come before test-skill"
[ "$test_pos" -lt "$zeta_pos" ] || fail "multi-skill order: test-skill should come before zeta"

# Failure path: skill bootstrap returning non-zero stops launch
mkdir -p "$FIXTURE/agents/failtest/skills/bad-skill/scripts"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/failtest"
cat > "$FIXTURE/agents/failtest/pi-args" <<'EOF'
--no-context-files
EOF

cat > "$FIXTURE/agents/failtest/skills/bad-skill/scripts/bootstrap.sh" <<'EOF'
echo "bad-skill: about to fail"
return 1
EOF

set +e
output=$(DOT_PI_DIR="$FIXTURE" DOTPI_DISPATCH_CAPTURE_PI=1 "$FIXTURE/bin/failtest" < /dev/null 2>&1)
status=$?
set -e
[ "$status" -ne 0 ] || fail "failing skill bootstrap: expected non-zero exit"
assert_contains "$output" "Bootstrap failed" "failing skill bootstrap message"
assert_contains "$output" "bad-skill" "failing skill bootstrap names skill"

# Skills without scripts/bootstrap.sh are silently skipped
mkdir -p "$FIXTURE/agents/searcher/skills/no-bootstrap-skill"
cat > "$FIXTURE/agents/searcher/skills/no-bootstrap-skill/SKILL.md" <<'EOF'
---
name: no-bootstrap-skill
description: Skill with no bootstrap
---
EOF

run_capture "skill without bootstrap skipped" "$FIXTURE/bin/searcher"
BOOTSTRAP_LOG="$FIXTURE/agents/searcher/sessions/bootstrap.log"
LOG_CONTENT=$(cat "$BOOTSTRAP_LOG")
assert_not_contains "$LOG_CONTENT" "no-bootstrap-skill" "skill without bootstrap not logged"

echo "dispatch-agent smoke: ok"
