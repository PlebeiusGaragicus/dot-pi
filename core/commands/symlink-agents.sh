# dotpi symlink-agents — add core/bin to PATH in shell rc (idempotent).
# Sourced by the dotpi dispatcher — do not execute directly.

# shellcheck source=core/commands/_common.sh
source "$COMMANDS_DIR/_common.sh"

# shellcheck source=core/install/path-rc.sh
source "$DOT_PI_DIR/core/install/path-rc.sh"

usage() {
  cat <<'EOF'
Usage: dotpi symlink-agents [--dry-run] [--rc FILE]

  Append or refresh a marked export PATH=... block for this package's core/bin
  in your shell rc file (default from $SHELL: .zshrc or .bashrc).

Options:
  --dry-run   Print actions only; do not write.
  --rc FILE   Use this rc file instead of detecting from $SHELL.
EOF
  exit 1
}

dry_run=0
rc_override=""

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    --rc)
      shift
      [ -n "${1:-}" ] || usage
      rc_override="$1"
      shift
      ;;
    -h | --help) usage ;;
    *)
      echo "dotpi: unknown option: $1" >&2
      usage
      ;;
  esac
done

rc_file=""
if [ -n "$rc_override" ]; then
  rc_file="$rc_override"
else
  if ! rc_file=$(dotpi_detect_rc_file); then
    bin_dir=$(dotpi_core_bin_dir) || exit 1
    line=$(dotpi_path_export_line) || exit 1
    line=${line%$'\n'}
    printf 'dotpi: could not detect shell rc from SHELL=%s\n' "${SHELL:-}" >&2
    printf 'Run with --rc FILE, or append manually, for example:\n\n' >&2
    printf '  echo %q >> ~/.zshrc\n' "$line" >&2
    printf '  echo %q >> ~/.bashrc\n' "$line" >&2
    printf '\nOr:\n\n' >&2
    printf '  %q symlink-agents --rc ~/.zshrc\n' "$DOT_PI_DIR/core/bin/dotpi" >&2
    exit 1
  fi
fi

if [ "$dry_run" = 1 ]; then
  dotpi_append_path_block "$rc_file" 1
  exit 0
fi

if dotpi_append_path_block "$rc_file" 0; then
  printf 'dotpi: updated %s\n' "$rc_file"
  printf 'Run: source %q (or open a new terminal)\n' "$rc_file"
else
  exit 1
fi
