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
    return 0
  fi

  mkdir -p "$(dirname "$rc_file")" 2>/dev/null || true
  touch "$rc_file" || {
    printf 'dotpi: cannot write %s\n' "$rc_file" >&2
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
  printf '=====================================================================\n'
  printf '\n'
}
