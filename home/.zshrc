# Interactive zsh setup: history, completion, integrations, and prompt.

# Load the shared environment for both login and non-login shells.
. "$HOME/.shell_common"

# OrbStack integration, when installed.
if [ -f "$HOME/.orbstack/shell/init.zsh" ]; then
    . "$HOME/.orbstack/shell/init.zsh"
fi

# History
HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt EXTENDED_HISTORY

# Completion
fpath+=(~/.zfunc)
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list \
  'm:{a-zA-Z}={A-Za-z}' \
  'r:|[._-]=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '[%d]'

if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
    export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
    eval "$(direnv hook zsh)"
fi

if command -v atuin >/dev/null 2>&1; then
    eval "$(atuin init zsh)"
fi

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init zsh)"
fi
