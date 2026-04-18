# Zsh tab completion for `p` (sourced from bash_aliases when ZSH_VERSION is set).
# Requires compsys: run `autoload -Uz compinit && compinit` in ~/.zshrc before sourcing bash_aliases.

_p() {
  if (( CURRENT > 2 )) || (( CURRENT == 1 )); then
    _default
    return
  fi
  [[ -z ${words[2]} ]] && return

  local -a dirs names
  dirs=()
  [[ -d "$DOT_PI_DIR/teams" ]] && dirs+=("$DOT_PI_DIR"/teams/*(/N))
  [[ -d "$DOT_PI_DIR/agents" ]] && dirs+=("$DOT_PI_DIR"/agents/*(/N))
  names=(${dirs:t})

  local expl
  _description names expl 'agent or team'
  compadd "$expl[@]" -M 'm:{a-zA-Z}={A-Za-z}' -a names
}
compdef _p p
