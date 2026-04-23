# Install

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install.sh)"
```

The installer will:
- Check for required tools (`git`, `curl`, `jq`)
- Install `pi` via npm if not already present
- Clone dot-pi to `~/.dot-pi`
- Add `source ~/.dot-pi/bash_aliases` to your shell config
- Run the interactive setup wizard (API keys, models, roles)

Override the install location with `DOT_PI_HOME`:

```bash
DOT_PI_HOME=~/my-agents bash -c "$(curl -fsSL https://raw.githubusercontent.com/PlebeiusGaragicus/dot-pi/main/install.sh)"
```

## Manual install

```bash
git clone https://github.com/PlebeiusGaragicus/dot-pi.git ~/.dot-pi
echo 'source ~/.dot-pi/bash_aliases' >> ~/.zshrc
source ~/.dot-pi/bash_aliases
~/.dot-pi/dotpi setup
```

## Uninstall

```bash
~/.dot-pi/install.sh --uninstall
```
