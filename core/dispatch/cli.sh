# dot-pi agent command grammar and prompt argument construction.

_cli_action="launch"
_cli_resume_target=""
_cli_prompt=""
_cli_has_prompt=false
_cli_print=false
_cli_verbose=false
_cli_error=""
_prompt_args=()

_build_prompt_args() {
  _prompt_args=()
  [ "$_cli_has_prompt" = true ] || return 0
  if [ "$_cli_print" = true ]; then
    _prompt_args+=(-p "$_cli_prompt")
  else
    _prompt_args+=("$_cli_prompt")
  fi
}

_parse_agent_cli() {
  shift
  local arg
  _cli_action="launch"
  _cli_resume_target=""
  _cli_prompt=""
  _cli_has_prompt=false
  _cli_print=false
  _cli_verbose=false
  _cli_error=""

  while [ $# -gt 0 ]; do
    case "$1" in
      -v|--verbose)
        _cli_verbose=true
        shift
        ;;
      *)
        break
        ;;
    esac
  done

  [ $# -eq 0 ] && return 0

  case "$1" in
    help|usage|-h|--help)
      if [ $# -ne 1 ]; then
        _cli_error="'$1' does not accept additional arguments"
        return 1
      fi
      _cli_action="help"
      return 0
      ;;
    ls)
      if [ $# -ne 1 ]; then
        _cli_error="'ls' does not accept additional arguments"
        return 1
      fi
      _cli_action="ls"
      return 0
      ;;
    resume)
      _cli_error="'resume' was removed with workspace mode; use 'ls' to inspect overlay-backed sessions"
      return 1
      ;;
  esac

  while [ $# -gt 0 ]; do
    arg="$1"
    shift
    case "$arg" in
      -v|--verbose)
        _cli_verbose=true
        ;;
      -p|--print)
        _cli_print=true
        ;;
      -n|--name)
        _cli_error="'$arg' was removed with workspace mode"
        return 1
        ;;
      -)
        if [ $# -eq 0 ]; then
          _cli_error="missing prompt after '-'"
          return 1
        fi
        _cli_prompt="$*"
        _cli_has_prompt=true
        return 0
        ;;
      -*)
        _cli_error="unknown option: $arg"
        return 1
        ;;
      *)
        if [ "$_cli_print" = true ]; then
          _cli_prompt="$arg"
          [ $# -gt 0 ] && _cli_prompt="$_cli_prompt $*"
          _cli_has_prompt=true
          return 0
        fi
        _cli_error="prompt text must follow '-'"
        return 1
        ;;
    esac
  done
}

_read_stdin_prompt_if_needed() {
  local stdin_prompt
  case "$_cli_action" in
    launch) ;;
    *) return 0 ;;
  esac
  if [ "$_cli_has_prompt" = false ] && [ ! -t 0 ]; then
    stdin_prompt=$(cat)
    if [ -n "$stdin_prompt" ]; then
      _cli_prompt="$stdin_prompt"
      _cli_has_prompt=true
    fi
  fi
}

