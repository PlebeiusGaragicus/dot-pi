# Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

The installer will:
- Check for required tools (`git`, `curl`, `jq`)
- Install `pi` via npm if not already present
- Clone dot-pi to `~/.dot-pi`
- Add `export PATH="$HOME/.dot-pi/bin:$PATH"` and `source "$HOME/.dot-pi/env.sh"` to your shell config
- Run the interactive setup wizard (API keys, models, roles)

Override the install location with `DOT_PI_HOME`:

```bash
DOT_PI_HOME=~/my-agents bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install)"
```

## Manual install

```bash
git clone https://github.com/PlebeiusGaragicus/dot-pi.git ~/.dot-pi
echo 'export PATH="$HOME/.dot-pi/bin:$PATH"' >> ~/.zshrc
echo 'source "$HOME/.dot-pi/env.sh"' >> ~/.zshrc
export PATH="$HOME/.dot-pi/bin:$PATH"
source "$HOME/.dot-pi/env.sh"
~/.dot-pi/dotpi setup
```

## Uninstall

```bash
~/.dot-pi/install --uninstall
```
