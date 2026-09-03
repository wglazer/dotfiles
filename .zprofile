# Homebrew works from either Apple Silicon or Intel locations.
if command -v brew >/dev/null 2>&1; then
    eval "$(brew shellenv)"
elif [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -x /usr/local/bin/brew ]; then
    eval "$(/usr/local/bin/brew shellenv)"
fi

. "$HOME/.shell_common"

# OrbStack integration, when installed.
if [ -f "$HOME/.orbstack/shell/init.zsh" ]; then
    . "$HOME/.orbstack/shell/init.zsh"
fi
