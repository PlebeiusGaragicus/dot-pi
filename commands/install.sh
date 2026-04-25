#!/usr/bin/env bash
# dotpi install <target> — opt-in add-on installer.
# Sourced by the dotpi dispatcher.

_install_toppers() {
  echo ""
  echo "  Installing pi-toppers (optional web UIs)..."
  echo ""

  if [ ! -f "$DOT_PI_DIR/.gitmodules" ] || ! grep -q pi-toppers "$DOT_PI_DIR/.gitmodules" 2>/dev/null; then
    echo "  Error: pi-toppers submodule not configured in .gitmodules."
    echo "  Your dot-pi clone may predate the submodule. Try: git pull"
    exit 1
  fi

  git -C "$DOT_PI_DIR" submodule update --init --recursive pi-toppers || {
    echo "  Error: failed to initialize pi-toppers submodule."
    exit 1
  }

  if [ ! -d "$DOT_PI_DIR/pi-toppers" ] || [ -z "$(ls -A "$DOT_PI_DIR/pi-toppers" 2>/dev/null)" ]; then
    echo "  Error: pi-toppers directory is empty after submodule init."
    exit 1
  fi

  local installed=0
  for dir in "$DOT_PI_DIR"/pi-toppers/*/; do
    [ -f "$dir/package.json" ] || continue
    local app
    app="$(basename "$dir")"
    echo "  npm install — $app"
    (cd "$dir" && npm install --no-audit --no-fund) || {
      echo "  Warning: npm install failed for $app"
    }
    installed=$((installed + 1))
  done

  echo ""
  if [ "$installed" -eq 0 ]; then
    echo "  No apps found in pi-toppers/."
  else
    echo "  Installed $installed app(s). To run one:"
    echo ""
    for dir in "$DOT_PI_DIR"/pi-toppers/*/; do
      [ -f "$dir/package.json" ] || continue
      echo "    cd $dir && npm run dev"
    done
  fi
  echo ""
}

case "${1:-}" in
  toppers)    _install_toppers ;;
  ""|--help|-h)
    cat <<EOF
Usage: dotpi install <target>

Targets:
  toppers   Initialize the pi-toppers submodule and npm install each app
EOF
    exit 1 ;;
  *)
    echo "Unknown install target: $1"
    exit 1 ;;
esac
