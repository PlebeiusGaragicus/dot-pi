#!/usr/bin/env bash
set -euo pipefail

REPO_URL="https://github.com/PlebeiusGaragicus/dot-pi.git"
DOT_PI_HOME="${DOT_PI_HOME:-$HOME/.dot-pi}"

# ── helpers ───────────────────────────────────────────────────────────────────

bold()  { printf '\033[1m%s\033[0m' "$*"; }
green() { printf '\033[32m%s\033[0m' "$*"; }
yellow(){ printf '\033[33m%s\033[0m' "$*"; }
red()   { printf '\033[31m%s\033[0m' "$*"; }

info()  { echo "  $(green "✓") $*"; }
warn()  { echo "  $(yellow "!") $*"; }
fail()  { echo "  $(red "✗") $*"; exit 1; }

confirm() {
  local prompt="$1" default="${2:-Y}"
  local yn
  if [ "$default" = "Y" ]; then
    read -r -p "  $prompt [Y/n] " yn
    [[ "${yn:-Y}" =~ ^[Yy]$ ]]
  else
    read -r -p "  $prompt [y/N] " yn
    [[ "${yn:-N}" =~ ^[Yy]$ ]]
  fi
}

shell_rc() {
  local sh
  sh="$(basename "${SHELL:-/bin/bash}")"
  case "$sh" in
    zsh)  echo "$HOME/.zshrc" ;;
    bash) echo "$HOME/.bashrc" ;;
    *)    echo "$HOME/.${sh}rc" ;;
  esac
}

usage() {
  cat <<EOF
dot-pi installer

Usage:
  install.sh              Install dot-pi to $DOT_PI_HOME
  install.sh --uninstall  Remove dot-pi and clean up shell config
  install.sh --help       Show this help

Environment:
  DOT_PI_HOME   Override install location (default: ~/.dot-pi)

One-liner:
  bash -c "\$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install.sh)"
EOF
  exit 0
}

# ── dependency checks ─────────────────────────────────────────────────────────

check_deps() {
  local missing=()
  for cmd in git curl jq; do
    command -v "$cmd" &>/dev/null || missing+=("$cmd")
  done
  if [ ${#missing[@]} -gt 0 ]; then
    echo ""
    red "  Missing required tools: ${missing[*]}"; echo ""
    echo ""
    echo "  Install them first:"
    if [[ "$OSTYPE" == darwin* ]]; then
      echo "    brew install ${missing[*]}"
    else
      echo "    sudo apt install ${missing[*]}   # Debian/Ubuntu"
      echo "    sudo dnf install ${missing[*]}   # Fedora"
    fi
    exit 1
  fi
}

check_pi() {
  if command -v pi &>/dev/null; then
    info "pi found: $(command -v pi)"
    return
  fi

  warn "pi (coding agent) not found on PATH"
  echo ""

  if ! command -v node &>/dev/null || ! command -v npm &>/dev/null; then
    red "  Node.js/npm not found — cannot auto-install pi."; echo ""
    echo "  Install Node.js first (https://nodejs.org), then:"
    echo "    npm install -g @mariozechner/pi-coding-agent"
    echo ""
    if ! confirm "Continue without pi?" "Y"; then
      exit 1
    fi
    return
  fi

  if confirm "Install pi via npm? (npm install -g @mariozechner/pi-coding-agent)" "Y"; then
    echo ""
    npm install -g @mariozechner/pi-coding-agent
    echo ""
    if command -v pi &>/dev/null; then
      info "pi installed successfully"
    else
      warn "pi was installed but not found on PATH — you may need to restart your shell"
    fi
  else
    warn "Skipping pi install — the 'p' command won't work until pi is installed"
  fi
}

# ── install ───────────────────────────────────────────────────────────────────

do_install() {
  echo ""
  echo "  $(bold "dot-pi installer")"
  echo "  ════════════════"
  echo ""
  echo "  Install location: $(bold "$DOT_PI_HOME")"
  echo ""

  check_deps
  check_pi
  echo ""

  # Clone or update
  if [ -d "$DOT_PI_HOME/.git" ]; then
    info "Existing installation found — updating"
    git -C "$DOT_PI_HOME" pull --ff-only
  elif [ -d "$DOT_PI_HOME" ]; then
    fail "$DOT_PI_HOME exists but is not a git repo. Remove it first or set DOT_PI_HOME."
  else
    info "Cloning dot-pi..."
    git clone "$REPO_URL" "$DOT_PI_HOME"
  fi
  echo ""

  # Shell RC integration
  local rc
  rc="$(shell_rc)"

  if grep -qF "dot-pi" "$rc" 2>/dev/null; then
    info "Shell config already set up in $rc"
  else
    if confirm "Add dot-pi to $rc?" "Y"; then
      {
        echo ""
        echo "# dot-pi — pi agent launcher"
        echo "source \"$DOT_PI_HOME/bash_aliases\""
      } >> "$rc"
      info "Added to $rc"
    else
      warn "Skipped — add this to your shell config manually:"
      echo "    source \"$DOT_PI_HOME/bash_aliases\""
    fi
  fi
  echo ""

  # Run the interactive setup wizard
  if confirm "Run interactive setup wizard? (API keys, models, roles)" "Y"; then
    echo ""
    "$DOT_PI_HOME/setup.sh" init
  else
    warn "Skipped — run it later with: $DOT_PI_HOME/setup.sh init"
  fi

  echo ""
  echo "  $(bold "Done!")"
  echo ""
  echo "  Restart your shell or run:"
  echo "    source $rc"
  echo ""
  echo "  Then try:"
  echo "    p              # list available agents"
  echo "    p <name>       # launch an agent"
  echo ""
}

# ── uninstall ─────────────────────────────────────────────────────────────────

do_uninstall() {
  echo ""
  echo "  $(bold "dot-pi uninstaller")"
  echo "  ══════════════════"
  echo ""

  if [ ! -d "$DOT_PI_HOME" ]; then
    warn "dot-pi not found at $DOT_PI_HOME — nothing to remove"
    exit 0
  fi

  echo "  This will remove: $(bold "$DOT_PI_HOME")"
  echo ""

  if ! confirm "Are you sure?" "N"; then
    echo "  Cancelled."
    exit 0
  fi
  echo ""

  # Remove source line from shell RC
  local rc
  rc="$(shell_rc)"

  if [ -f "$rc" ] && grep -qF "dot-pi" "$rc" 2>/dev/null; then
    # Remove the comment line and the source line
    local tmp
    tmp="$(mktemp)"
    grep -vF "dot-pi" "$rc" > "$tmp"
    # Clean up any resulting double blank lines
    cat -s "$tmp" > "$rc"
    rm -f "$tmp"
    info "Removed dot-pi lines from $rc"
  fi

  # Remove the directory
  rm -rf "$DOT_PI_HOME"
  info "Removed $DOT_PI_HOME"
  echo ""

  # Optionally uninstall pi
  if command -v pi &>/dev/null; then
    if confirm "Also uninstall pi (npm global package)?" "N"; then
      npm uninstall -g @mariozechner/pi-coding-agent
      info "pi uninstalled"
    fi
  fi

  echo ""
  echo "  $(bold "dot-pi has been removed.")"
  echo "  Restart your shell to complete cleanup."
  echo ""
}

# ── main ──────────────────────────────────────────────────────────────────────

case "${1:-}" in
  --uninstall) do_uninstall ;;
  --help|-h)   usage ;;
  "")          do_install ;;
  *)           echo "Unknown option: $1"; usage ;;
esac
