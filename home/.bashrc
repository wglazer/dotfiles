# Interactive Bash entrypoint.

# Bash compatibility entrypoint.
. "$HOME/.shell_common"

# Shell-specific interactive integrations.
case "$-" in
    *i*)
        if command -v fzf >/dev/null 2>&1; then
            eval "$(fzf --bash)"
        fi
        if command -v zoxide >/dev/null 2>&1; then
            eval "$(zoxide init bash)"
        fi
        if command -v atuin >/dev/null 2>&1; then
            eval "$(atuin init bash)"
        fi
        if command -v starship >/dev/null 2>&1; then
            eval "$(starship init bash)"
        fi
        # Load after other prompt hooks so direnv updates the environment first.
        if command -v direnv >/dev/null 2>&1; then
            eval "$(direnv hook bash)"
        fi
        ;;
esac
