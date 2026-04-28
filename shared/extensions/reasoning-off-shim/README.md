# Reasoning Off Shim

Translates Pi's "thinking off" behavior into an explicit OpenAI-compatible
chat-completions disable request.

## Why This Exists

Pi represents `--thinking off` by omitting reasoning controls from the provider
request. Some OpenAI-compatible backends, including LM Studio-style chat
completions endpoints, treat a missing `reasoning_effort` as "use the server
default" rather than "disable reasoning".

For those backends, reasoning is disabled by explicitly sending:

```json
{
  "reasoning_effort": "none"
}
```

## How It Works

The extension registers `before_provider_request` and inspects outgoing
provider payloads. When the payload looks like an OpenAI chat-completions
request and does not already contain a reasoning control field, it returns a
shallow-cloned payload with `reasoning_effort: "none"`.

It does not override requests that already include any of:

- `reasoning_effort`
- `reasoning`
- `thinking`
- `enable_thinking`
- `chat_template_kwargs`

This preserves explicit reasoning settings such as `low`, `medium`, or `high`.

## Wiring

This extension is part of the standard top-level extension bundle and the
subagent extension bundle. `dotpi create`, `dotpi create-agent`, and `dotpi sync`
wire those bundles into agent config roots.

See `docs/reference/extensions.md` for the bundle layout and rules.
