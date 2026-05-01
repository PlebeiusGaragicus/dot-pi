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

run_expect_failure() {
  local label="$1"
  shift
  local output status
  set +e
  output=$(DOT_PI_DIR="$FIXTURE" DOTPI_DISPATCH_CAPTURE_PI=1 "$@" < /dev/null 2>&1)
  status=$?
  set -e
  [ "$status" -ne 0 ] || fail "$label expected failure; got success: $output"
  CAPTURE_OUT="$output"
}

mkdir -p "$FIXTURE/bin" "$FIXTURE/agents/coder" "$FIXTURE/agents/lm" \
  "$FIXTURE/agents/browser" "$FIXTURE/shared" \
  "$FIXTURE/workspaces/browser/2026-04-29-000000--prefix/sessions"
ln -s "$ROOT/lib" "$FIXTURE/lib"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/coder"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/lm"
ln -s "$ROOT/dispatch-agent" "$FIXTURE/bin/browser"

cat > "$FIXTURE/model-defaults" <<'EOF'
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
EOF

cat > "$FIXTURE/shared/models.json" <<'EOF'
{
  "providers": {
    "lmstudio": {
      "models": [
        { "id": "valid-fast" },
        { "id": "valid-agentic" }
      ]
    }
  }
}
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

printf 'lmstudio/valid-agentic\n' > "$FIXTURE/agents/coder/.model"
run_capture "coder valid agent model" "$FIXTURE/bin/coder"
assert_contains "$CAPTURE_OUT" $'\t--model\tlmstudio/valid-agentic' "coder valid agent model"

printf 'missing/provider-model\n' > "$FIXTURE/agents/coder/.model"
run_expect_failure "coder stale agent model" "$FIXTURE/bin/coder"
assert_contains "$CAPTURE_OUT" 'Model "missing/provider-model" from ' "coder stale agent model"
assert_contains "$CAPTURE_OUT" "agents/coder/.model" "coder stale agent model"
assert_contains "$CAPTURE_OUT" "Run: dotpi models" "coder stale agent model"
rm -f "$FIXTURE/agents/coder/.model"

run_capture "lm interactive prompt" "$FIXTURE/bin/lm" - hi there
assert_contains "$CAPTURE_OUT" $'\t--thinking\toff' "lm interactive prompt"
assert_contains "$CAPTURE_OUT" $'\thi there' "lm interactive prompt"
assert_not_contains "$CAPTURE_OUT" $'\t--mode\tjson' "lm interactive prompt"
assert_not_contains "$CAPTURE_OUT" $'\t-p\t' "lm interactive prompt"

cat > "$FIXTURE/model-defaults" <<'EOF'
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-missing/fast}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
EOF
run_expect_failure "lm stale model default" "$FIXTURE/bin/lm" - hi
assert_contains "$CAPTURE_OUT" 'Model "missing/fast" from ' "lm stale model default"
assert_contains "$CAPTURE_OUT" "model-defaults (DEFAULT_FAST_MODEL)" "lm stale model default"
assert_contains "$CAPTURE_OUT" "Run: dotpi models" "lm stale model default"
cat > "$FIXTURE/model-defaults" <<'EOF'
export DEFAULT_AGENTIC_MODEL="${DEFAULT_AGENTIC_MODEL:-}"
export DEFAULT_FAST_MODEL="${DEFAULT_FAST_MODEL:-}"
export DEFAULT_VLM_MODEL="${DEFAULT_VLM_MODEL:-}"
EOF

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

run_capture_stdin "browser picker resume prompt" $'3\n' "$FIXTURE/bin/browser" resume - continue from picker
assert_contains "$CAPTURE_OUT" "Workspaces for browser:" "browser picker resume prompt"
assert_contains "$CAPTURE_OUT" "Resuming: $FIXTURE/workspaces/browser/" "browser picker resume prompt"
assert_contains "$CAPTURE_OUT" $'\tcontinue from picker' "browser picker resume prompt"

echo "dispatch-agent smoke: ok"
