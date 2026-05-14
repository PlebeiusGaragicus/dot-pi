# dotpi keys — view and edit overlay API keys (Exa, Tavily, ntfy)
# Sourced by the dotpi dispatcher — do not execute directly.

# shellcheck source=core/commands/_common.sh
source "$COMMANDS_DIR/_common.sh"

_keys_usage() {
  cat <<EOF
Usage: dotpi keys [status|help]

  (no args)   Interactive menu: view masked keys, set, clear, optional ntfy probe
  status      Print masked status (safe for scripts; no prompts)
  help        Show this help

Overlay directory: \$DOT_PI_OVERLAY (${DOT_PI_OVERLAY})
Files: env.exa, env.tavily, env.ntfy

In pi, use /api-keys for the same edits with the TUI.
EOF
}

_keys_mask_secret() {
  local s="$1"
  if [ -z "$s" ]; then
    printf '%s\n' "(not set)"
    return
  fi
  local len=${#s}
  if [ "$len" -le 6 ]; then
    printf '%s\n' "****"
    return
  fi
  printf '%s\n' "${s:0:4}****${s: -2}"
}

_keys_read_exa() {
  local v="${EXA_API_KEY:-}"
  v="${v//$'\r'/}"
  v=$(printf '%s' "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -n "$v" ] && [ "$v" != "\$EXA_API_KEY" ]; then
    printf '%s\n' "$v"
    return
  fi
  local f="$DOT_PI_OVERLAY/env.exa"
  [ -f "$f" ] || return 0
  local line
  line=$(grep -v '^[[:space:]]*#' "$f" | grep -m1 -E '^(EXA_API_KEY[[:space:]]*=)?' || true)
  line="${line#EXA_API_KEY=}"
  line="${line#exa_api_key=}"
  printf '%s\n' "$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
}

_keys_write_exa() {
  local key="$1"
  mkdir -p "$DOT_PI_OVERLAY"
  (
    umask 077
    printf 'EXA_API_KEY=%s\n' "$key" >"$DOT_PI_OVERLAY/env.exa"
  )
  echo "Wrote $DOT_PI_OVERLAY/env.exa"
}

_keys_read_tavily() {
  local v="${TAVILY_API_KEY:-}"
  v="${v//$'\r'/}"
  v=$(printf '%s' "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -n "$v" ] && [ "$v" != "\$TAVILY_API_KEY" ]; then
    printf '%s\n' "$v"
    return
  fi
  local f="$DOT_PI_OVERLAY/env.tavily"
  [ -f "$f" ] || return 0
  local line
  line=$(grep -v '^[[:space:]]*#' "$f" | grep -m1 -E '^(TAVILY_API_KEY[[:space:]]*=)?' || true)
  line="${line#TAVILY_API_KEY=}"
  printf '%s\n' "$(printf '%s' "$line" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
}

_keys_write_tavily() {
  local key="$1"
  mkdir -p "$DOT_PI_OVERLAY"
  (
    umask 077
    printf 'TAVILY_API_KEY=%s\n' "$key" >"$DOT_PI_OVERLAY/env.tavily"
  )
  echo "Wrote $DOT_PI_OVERLAY/env.tavily"
}

_keys_ntfy_get() {
  local key="$1" v="" f="$DOT_PI_OVERLAY/env.ntfy" line=""
  case "$key" in
    NTFY_BASE_URL) v="${NTFY_BASE_URL:-}" ;;
    NTFY_USER) v="${NTFY_USER:-}" ;;
    NTFY_PASSWORD) v="${NTFY_PASSWORD:-}" ;;
    *) return 0 ;;
  esac
  v=$(printf '%s' "$v" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if [ -n "$v" ] && [ "$v" != "\$${key}" ]; then
    printf '%s\n' "$v"
    return 0
  fi
  [ -f "$f" ] || return 0
  line=$(grep -v '^[[:space:]]*#' "$f" | grep -m1 "^${key}=" || true)
  [ -n "$line" ] || return 0
  printf '%s\n' "${line#"${key}="}" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

_keys_write_ntfy_file() {
  local url="$1" user="$2" pass="$3"
  mkdir -p "$DOT_PI_OVERLAY"
  local f="$DOT_PI_OVERLAY/env.ntfy"
  (
    umask 077
    {
      printf '# dot-pi ntfy (written by dotpi keys)\n'
      printf 'NTFY_BASE_URL=%s\n' "$url"
      printf 'NTFY_USER=%s\n' "$user"
      printf 'NTFY_PASSWORD=%s\n' "$pass"
    } >"$f"
  )
  echo "Wrote $f"
}

_keys_ntfy_probe() {
  local base="$1"
  base="${base%/}"
  if ! command -v curl &>/dev/null; then
    echo "Warning: curl not found; skipping probe."
    return 1
  fi
  if curl -fsS --max-time 8 "${base}/version" >/dev/null 2>&1; then
    echo "ntfy probe: OK (${base}/version)"
    return 0
  fi
  echo "Warning: ntfy probe failed for ${base}/version (server may use a different path or require auth)."
  return 1
}

_keys_prompt_line() {
  local label="$1"
  local current_masked="$2"
  local out
  read -r -p "$label [Enter=keep, -=clear] (current: $current_masked): " out || true
  printf '%s' "${out:-}"
}

_keys_status() {
  local exa tav nurl nu np
  exa=$(_keys_read_exa)
  tav=$(_keys_read_tavily)
  nurl=$(_keys_ntfy_get NTFY_BASE_URL) || nurl=""
  nu=$(_keys_ntfy_get NTFY_USER) || nu=""
  np=$(_keys_ntfy_get NTFY_PASSWORD) || np=""
  echo "DOT_PI_OVERLAY=$DOT_PI_OVERLAY"
  echo "Exa API key:    $(_keys_mask_secret "$exa")"
  echo "Tavily API key: $(_keys_mask_secret "$tav")"
  if [ -z "$nurl" ]; then
    echo "ntfy base URL: (not set)"
  else
    echo "ntfy base URL: $nurl"
  fi
  if [ -n "$nu" ] || [ -n "$np" ]; then
    echo "ntfy user:      $(_keys_mask_secret "$nu")"
    echo "ntfy password:  $(_keys_mask_secret "$np")"
  fi
}

_keys_edit_exa() {
  local cur masked val
  cur=$(_keys_read_exa)
  masked=$(_keys_mask_secret "$cur")
  val=$(_keys_prompt_line "Exa API key" "$masked")
  if [ "$val" = "-" ]; then
    rm -f "$DOT_PI_OVERLAY/env.exa"
    echo "Cleared env.exa"
  elif [ -n "$val" ]; then
    _keys_write_exa "$val"
  else
    echo "Unchanged."
  fi
}

_keys_edit_tavily() {
  local cur masked val
  cur=$(_keys_read_tavily)
  masked=$(_keys_mask_secret "$cur")
  val=$(_keys_prompt_line "Tavily API key" "$masked")
  if [ "$val" = "-" ]; then
    rm -f "$DOT_PI_OVERLAY/env.tavily"
    echo "Cleared env.tavily"
  elif [ -n "$val" ]; then
    _keys_write_tavily "$val"
  else
    echo "Unchanged."
  fi
}

_keys_edit_ntfy() {
  local cur_url cur_u cur_p url u p yn
  cur_url=$(_keys_ntfy_get NTFY_BASE_URL) || cur_url=""
  cur_u=$(_keys_ntfy_get NTFY_USER) || cur_u=""
  cur_p=$(_keys_ntfy_get NTFY_PASSWORD) || cur_p=""

  url=$(_keys_prompt_line "NTFY_BASE_URL" "${cur_url:-\(not set\)}")
  if [ "$url" = "-" ]; then
    rm -f "$DOT_PI_OVERLAY/env.ntfy"
    echo "Cleared env.ntfy"
    return
  fi
  if [ -z "$url" ]; then url="$cur_url"; fi

  u=$(_keys_prompt_line "NTFY_USER (optional)" "$(_keys_mask_secret "$cur_u")")
  if [ "$u" = "-" ]; then u=""; fi
  if [ -z "$u" ] && [ -n "$cur_u" ]; then u="$cur_u"; fi

  p=$(_keys_prompt_line "NTFY_PASSWORD (optional)" "$(_keys_mask_secret "$cur_p")")
  if [ "$p" = "-" ]; then p=""; fi
  if [ -z "$p" ] && [ -n "$cur_p" ]; then p="$cur_p"; fi

  if [ -z "$url" ]; then
    echo "NTFY_BASE_URL is required to save. Unchanged."
    return
  fi
  _keys_write_ntfy_file "$url" "$u" "$p"

  read -r -p "Test ntfy server now with GET .../version? [y/N] " yn || true
  case "${yn:-}" in
    y|Y) _keys_ntfy_probe "$url" || true ;;
    *) ;;
  esac
}

_keys_menu() {
  local choice
  while true; do
    echo ""
    echo "dotpi keys — select an action"
    echo "----------------------------"
    echo "  1) Show status"
    echo "  2) Set or clear Exa API key"
    echo "  3) Set or clear Tavily API key"
    echo "  4) Edit ntfy (NTFY_BASE_URL / user / password)"
    echo "  q) Quit"
    echo ""
    read -r -p "Choice: " choice || exit 0
    case "$choice" in
      1) _keys_status ;;
      2) _keys_edit_exa ;;
      3) _keys_edit_tavily ;;
      4) _keys_edit_ntfy ;;
      q|Q) echo "Bye."; exit 0 ;;
      *) echo "Invalid choice." ;;
    esac
  done
}

sub="${1:-}"
case "$sub" in
  help|-h|--help)
    _keys_usage
    exit 0
    ;;
  status)
    _keys_status
    exit 0
    ;;
  "")
    if [ ! -t 0 ] || [ ! -t 1 ]; then
      echo "Error: interactive dotpi keys requires a terminal." >&2
      echo "Run: dotpi keys status   (non-interactive)" >&2
      exit 1
    fi
    _keys_menu
    ;;
  *)
    echo "Error: unknown argument '$sub'" >&2
    _keys_usage >&2
    exit 1
    ;;
esac
