#!/usr/bin/env bash
# dotpi doctor — health-check the dot-pi installation.
# Sourced by the dotpi dispatcher.

_strict=false
[ "${1:-}" = "--strict" ] && _strict=true

_fails=0
_warns=0

_ok()   { echo "  [OK]   $*"; }
_warn() { echo "  [WARN] $*"; _warns=$((_warns + 1)); }
_fail() { echo "  [FAIL] $*"; _fails=$((_fails + 1)); }

echo ""
echo "  dotpi doctor"
echo "  ════════════"
echo ""

# 1. pi on PATH
if command -v pi &>/dev/null; then
  _ok "pi found: $(command -v pi)"
else
  _fail "pi not found on PATH"
fi

# 2. env.sh sourced
if [ "${DOT_PI_INSTALLED:-}" = "1" ]; then
  _ok "env.sh sourced (DOT_PI_INSTALLED=1)"
else
  _warn "env.sh not sourced — DOT_PI_INSTALLED is not set"
fi

# 3. model-defaults exists
if [ -f "$DOT_PI_DIR/model-defaults" ]; then
  _ok "model-defaults exists"
else
  _warn "model-defaults file not found (bootstrap: cp bootstrap/model-defaults.example model-defaults)"
fi

# 4. shared/settings.json
if [ -f "$DOT_PI_DIR/shared/settings.json" ]; then
  _ok "shared/settings.json exists"
else
  _warn "shared/settings.json missing (bootstrap: cp bootstrap/settings.json.example shared/settings.json)"
fi

# 5. shared/auth.json
if [ -f "$DOT_PI_DIR/shared/auth.json" ]; then
  _ok "shared/auth.json exists"
else
  _warn "shared/auth.json missing (bootstrap: dotpi sync or cp bootstrap/auth.json.example shared/auth.json)"
fi

# 6. shared/models.json symlink
if [ -L "$DOT_PI_DIR/shared/models.json" ]; then
  _target="$(readlink "$DOT_PI_DIR/shared/models.json")"
  if [ -f "$DOT_PI_DIR/shared/models.json" ]; then
    _ok "shared/models.json -> $_target"
  else
    _fail "shared/models.json symlink broken -> $_target"
  fi
elif [ -f "$DOT_PI_DIR/shared/models.json" ]; then
  _warn "shared/models.json is a regular file (expected symlink to ~/.pi/agent/models.json)"
else
  _fail "shared/models.json missing"
fi

# 7. bin/ on PATH
if echo "$PATH" | tr ':' '\n' | grep -qF "$DOT_PI_DIR/bin" 2>/dev/null ||
   echo "$PATH" | tr ':' '\n' | grep -qF "$HOME/.dot-pi/bin" 2>/dev/null; then
  _ok "bin/ is on PATH"
else
  _warn "bin/ not found on PATH — add to your shell RC: export PATH=\"\$HOME/.dot-pi/bin:\$PATH\""
fi

# 8. Per-agent config checks
_check_agent_dir() {
  local dir="$1" label="$2"
  local _had_fail=false

  # bin symlink
  if [ -L "$dir/bin" ]; then
    if [ -d "$dir/bin" ]; then
      :
    else
      _fail "$label: bin/ symlink broken"
      _had_fail=true
    fi
  else
    _fail "$label: bin/ is not a symlink"
    _had_fail=true
  fi

  # models.json symlink
  if [ -L "$dir/models.json" ]; then
    if [ -f "$dir/models.json" ]; then
      :
    else
      _fail "$label: models.json symlink broken"
      _had_fail=true
    fi
  elif [ ! -f "$dir/models.json" ]; then
    _fail "$label: models.json missing"
    _had_fail=true
  fi

  # settings.json symlink
  if [ -L "$dir/settings.json" ]; then
    if [ -f "$dir/settings.json" ]; then
      :
    else
      _fail "$label: settings.json symlink broken"
      _had_fail=true
    fi
  elif [ ! -f "$dir/settings.json" ]; then
    _warn "$label: settings.json missing"
  fi

  # extensions/ — check for broken symlinks
  if [ -d "$dir/extensions" ]; then
    for ext in "$dir"/extensions/*/; do
      [ -d "$ext" ] && continue
      [ -L "$ext" ] || continue
      _fail "$label: broken extension symlink $(basename "$ext")"
      _had_fail=true
    done
    for ext in "$dir"/extensions/*.ts; do
      [ -f "$ext" ] && continue
      [ -L "$ext" ] || continue
      _fail "$label: broken extension symlink $(basename "$ext")"
      _had_fail=true
    done
  fi

  # auth.json (symlink to shared, like models.json)
  if [ -L "$dir/auth.json" ]; then
    if [ ! -f "$dir/auth.json" ]; then
      _fail "$label: auth.json symlink broken"
      _had_fail=true
    else
      _atarget="$(readlink "$dir/auth.json")"
      case "$_atarget" in
        ../../shared/auth.json|"$DOT_PI_DIR/shared/auth.json") ;;
        *)
          _warn "$label: auth.json -> $_atarget (expected ../../shared/auth.json — run dotpi sync)"
          ;;
      esac
    fi
  elif [ -f "$dir/auth.json" ]; then
    _warn "$label: auth.json is a regular file (merge into shared/auth.json then dotpi sync)"
  else
    _warn "$label: auth.json missing (run dotpi sync)"
  fi

  if [ "$_had_fail" = false ]; then
    _ok "$label: symlinks OK"
  fi
}

for d in "$DOT_PI_DIR"/agents/*/; do
  [ -d "$d" ] || continue
  _check_agent_dir "$d" "agents/$(basename "$d")"
done

# 9. Optional binaries
for _bin in fd rg; do
  if [ -f "$DOT_PI_DIR/shared/bin/$_bin" ]; then
    _ok "shared/bin/$_bin found"
  else
    _warn "shared/bin/$_bin not found (pi downloads these on first run)"
  fi
done

# Summary
echo ""
if [ "$_fails" -gt 0 ]; then
  echo "  $_fails failure(s), $_warns warning(s)"
  echo ""
  exit 1
elif [ "$_warns" -gt 0 ] && [ "$_strict" = true ]; then
  echo "  $_warns warning(s) (--strict: treating as failures)"
  echo ""
  exit 1
elif [ "$_warns" -gt 0 ]; then
  echo "  $_warns warning(s), 0 failures"
  echo ""
  exit 0
else
  echo "  All checks passed."
  echo ""
  exit 0
fi
