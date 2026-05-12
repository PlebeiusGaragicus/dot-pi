#!/usr/bin/env bash
# PATH detection and shell rc helpers for dot-pi (sourced after DOT_PI_DIR is set).

dotpi_core_bin_dir() {
  [ -n "${DOT_PI_DIR:-}" ] || return 1
  (cd "$DOT_PI_DIR/core/bin" && pwd)
}

dotpi_resolve_path() {
  local p="$1"
  readlink -f "$p" 2>/dev/null || realpath "$p" 2>/dev/null || printf '%s\n' "$p"
}

# First agent name under core/bin suitable for PATH probing (prefer ask).
dotpi_path_probe_name() {
  local bin_dir="$1"
  local f base tgt
  [ -d "$bin_dir" ] || return 1
  if [ -e "$bin_dir/ask" ]; then
    printf 'ask\n'
    return 0
  fi
  for f in "$bin_dir"/*; do
    [ -e "$f" ] || [ -L "$f" ] || continue
    base=$(basename "$f")
    case "$base" in dotpi | todo) continue ;; esac
    [ -L "$f" ] || continue
    tgt=$(readlink "$f" 2>/dev/null || true)
    case "$tgt" in
      ../../dispatch-agent | */dispatch-agent)
        printf '%s\n' "$base"
        return 0
        ;;
    esac
  done
  return 1
}

# True (0) if the first matching probe on PATH resolves to this tree's launcher.
dotpi_core_bin_on_path() {
  local bin_dir probe our_path cmd_path our_res cmd_res
  bin_dir=$(dotpi_core_bin_dir) || return 1
  probe=$(dotpi_path_probe_name "$bin_dir") || return 1
  our_path="$bin_dir/$probe"
  [ -e "$our_path" ] || return 1
  cmd_path=$(PATH="${PATH:-}" command -v "$probe" 2>/dev/null) || return 1
  our_res=$(dotpi_resolve_path "$our_path")
  cmd_res=$(dotpi_resolve_path "$cmd_path")
  [ -n "$our_res" ] && [ "$our_res" = "$cmd_res" ]
}

# Echo rc file path for current login shell, or exit 1 if unknown.
dotpi_detect_rc_file() {
  case "${SHELL:-}" in
    */zsh)
      printf '%s\n' "${ZDOTDIR:-$HOME}/.zshrc"
      ;;
    */bash)
      printf '%s\n' "$HOME/.bashrc"
      ;;
    *)
      return 1
      ;;
  esac
}

dotpi_path_block_begin() { printf '%s\n' '# BEGIN_DOT_PI_PATH'; }
dotpi_path_block_end() { printf '%s\n' '# END_DOT_PI_PATH'; }

dotpi_path_export_line() {
  local bin_dir
  bin_dir=$(dotpi_core_bin_dir) || return 1
  printf 'export PATH="%s:$PATH"\n' "$bin_dir"
}

# True if we can create or update rc_file as the current user.
dotpi_rc_target_writable() {
  local rc_file="$1" dir
  dir=$(dirname "$rc_file")
  if [ -e "$rc_file" ]; then
    [ -w "$rc_file" ] && return 0
    return 1
  fi
  mkdir -p "$dir" 2>/dev/null || true
  [ -w "$dir" ] && return 0
  return 1
}

# Explain ownership / parent-dir issues (shared by permission and move failures).
dotpi_print_rc_ownership_fixup() {
  local rc_file="$1" dir
  if [ -e "$rc_file" ]; then
    printf '\nThis file exists but is not writable by your user. Common cause: it was created or edited with sudo and is owned by root.\n\n' >&2
    ls -la "$rc_file" 2>/dev/null | sed 's/^/  /' >&2 || true
    printf '\nFix ownership, then run symlink-agents again:\n\n' >&2
    printf '  sudo chown "$(whoami)" %q\n' "$rc_file" >&2
    printf '\n(Use your normal account; avoid running dotpi symlink-agents with sudo.)\n' >&2
    return 0
  fi
  dir=$(dirname "$rc_file")
  printf '\nCannot create %q (parent directory not writable).\n\n' "$rc_file" >&2
  ls -ld "$dir" 2>/dev/null | sed 's/^/  /' >&2 || true
  printf '\nExample fix:\n\n' >&2
  printf '  sudo chown "$(whoami)" %q\n' "$dir" >&2
}

# Explain permission errors (e.g. ~/.zshrc owned by root after a past sudo edit).
dotpi_print_rc_permission_help() {
  local rc_file="$1"
  printf 'dotpi: cannot write %q\n' "$rc_file" >&2
  dotpi_print_rc_ownership_fixup "$rc_file"
}

# Idempotent: remove old marked block if present, append fresh block.
# Args: rc_file [dry_run: 1 or 0]
dotpi_append_path_block() {
  local rc_file="${1:?rc file}" dry_run="${2:-0}"
  local bin_dir begin end line tmp
  begin='# BEGIN_DOT_PI_PATH'
  end='# END_DOT_PI_PATH'
  bin_dir=$(dotpi_core_bin_dir) || return 1
  line=$(dotpi_path_export_line) || return 1
  line=${line%$'\n'}

  if [ "$dry_run" = 1 ]; then
    printf 'Would update %s with:\n' "$rc_file"
    dotpi_path_block_begin
    printf '%s\n' "$line"
    dotpi_path_block_end
    if ! dotpi_rc_target_writable "$rc_file"; then
      printf '\nWarning: %q is not writable; a real run would fail.\n' "$rc_file" >&2
      dotpi_print_rc_ownership_fixup "$rc_file"
      printf '\n(--dry-run only; fix permissions above, then run without --dry-run.)\n' >&2
    fi
    return 0
  fi

  if ! dotpi_rc_target_writable "$rc_file"; then
    dotpi_print_rc_permission_help "$rc_file"
    return 1
  fi

  mkdir -p "$(dirname "$rc_file")" 2>/dev/null || true
  touch "$rc_file" || {
    dotpi_print_rc_permission_help "$rc_file"
    return 1
  }

  tmp="${rc_file}.dotpi.$$"
  if grep -qF "$begin" "$rc_file" 2>/dev/null; then
    awk -v b="$begin" -v e="$end" '$0 == b { d = 1; next } $0 == e { d = 0; next } !d { print }' "$rc_file" >"$tmp" || return 1
  else
    cat "$rc_file" >"$tmp" || return 1
  fi
  {
    printf '\n'
    dotpi_path_block_begin
    printf '%s\n' "$line"
    dotpi_path_block_end
  } >>"$tmp" || return 1
  mv "$tmp" "$rc_file" || {
    rm -f "$tmp"
    printf 'dotpi: could not replace %q (move failed).\n' "$rc_file" >&2
    if [ -e "$rc_file" ] && [ ! -w "$rc_file" ]; then
      dotpi_print_rc_ownership_fixup "$rc_file"
    fi
    return 1
  }
  return 0
}

# Postinstall messaging (stdout). Uses DOT_PI_DIR.
dotpi_postinstall_path_hint() {
  local bin_dir dotpi_abs
  bin_dir=$(dotpi_core_bin_dir) || return 1
  dotpi_abs="$bin_dir/dotpi"
  if dotpi_core_bin_on_path; then
    printf 'postinstall: agent commands on PATH (%s)\n' "$bin_dir"
    return 0
  fi
  printf '\n'
  printf '=====================================================================\n'
  printf 'Run this command to add agent commands to your PATH:\n'
  printf '\n'
  printf '  "%s" symlink-agents\n' "$dotpi_abs"
  printf '\n'
  printf 'Then open a new terminal, or run: source ~/.zshrc   (or ~/.bashrc)\n'
  printf 'If that command reports permission denied, dot-pi prints a chown fix — or see docs/install.md (PATH for agent commands).\n'
  printf '=====================================================================\n'
  printf '\n'
}
