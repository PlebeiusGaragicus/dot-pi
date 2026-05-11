# Shared dispatch runtime environment. Sourced by dispatch-agent after it has
# self-located DOT_PI_DIR; all launched pi and subagent processes inherit this.

export DOT_PI_DIR
export PI_TELEMETRY="${PI_TELEMETRY:-0}"
export DOT_PI_OVERLAY="${DOT_PI_OVERLAY:-$HOME/.pi/dot-pi}"

if [ -z "${B:-}" ]; then
  _dotpi_browser_control_bin="$DOT_PI_DIR/core/utilities/browser-runtime/dist/browser-control"
  if [ -x "$_dotpi_browser_control_bin" ]; then
    export B="$_dotpi_browser_control_bin"
  else
    export B="bun run $DOT_PI_DIR/core/utilities/browser-runtime/src/cli.ts"
  fi
  unset _dotpi_browser_control_bin
fi

_pi_args=()
_dispatch_cmd_args=()
_inline_model_defaults=":"
