# dot-pi agent command grammar and prompt argument construction.

_cli_action="launch"
_cli_workspace_name=""
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
  local config_dir="$1"
  shift
  local is_workspace=false arg
  _is_workspace_agent "$config_dir" && is_workspace=true
  _cli_action="launch"
  _cli_workspace_name=""
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
      if [ "$is_workspace" != true ]; then
        _cli_error="'resume' is only available for workspace agents"
        return 1
      fi
      _cli_action="resume"
      shift
      while [ $# -gt 0 ]; do
        case "$1" in
          -v|--verbose)
            _cli_verbose=true
            shift
            ;;
          -p|--print)
            _cli_print=true
            shift
            ;;
          -)
            shift
            if [ $# -eq 0 ]; then
              _cli_error="missing prompt after '-'"
              return 1
            fi
            _cli_prompt="$*"
            _cli_has_prompt=true
            break
            ;;
          -*)
            _cli_error="unknown resume option: $1"
            return 1
            ;;
          *)
            if [ "$_cli_print" = true ]; then
              _cli_prompt="$*"
              _cli_has_prompt=true
              break
            fi
            if [ -n "$_cli_resume_target" ]; then
              _cli_error="resume accepts at most one workspace name or path"
              return 1
            fi
            _cli_resume_target="$1"
            shift
            ;;
        esac
      done
      return 0
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
        if [ "$is_workspace" != true ]; then
          _cli_error="'$arg' is only available for workspace agents"
          return 1
        fi
        if [ $# -eq 0 ]; then
          _cli_error="$arg requires a workspace name"
          return 1
        fi
        _cli_workspace_name="$1"
        shift
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
    launch|resume) ;;
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

