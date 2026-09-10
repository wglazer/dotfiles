#!/usr/bin/env bash

# Run this file from a terminal with `./bootstrap.sh`; do not source it.
# It installs the Brewfile, backs up existing config files, and creates links
# from this repository into your home directory. Use `--dry-run` to preview it.
# `set -euo pipefail` makes Bash stop on errors, unset variables, and failures
# inside pipelines.
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DRY_RUN=0
SKIP_BREW=0

OP_ACCOUNT="${DOTFILES_OP_ACCOUNT:-osedea}"

usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [options]

Install Homebrew packages from Brewfile and symlink the repository configs.

The script finds this repository automatically, so it can be run from any
directory. Existing files are backed up before they are replaced.

Options:
  --dry-run    Show the actions without changing the machine.
  --skip-brew  Skip Homebrew installation and Brewfile processing.
  -h, --help   Show this help.
EOF
}

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --skip-brew) SKIP_BREW=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

[ "$(uname -s)" = Darwin ] || die "This bootstrap currently supports macOS only."
[ -d "$HOME" ] || die "HOME is not set to a valid directory."

BACKUP_ROOT="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

find_brew() {
    local candidate
    candidate="$(command -v brew 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew; do
        if [ -x "$candidate" ]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

install_brew() {
    local brew_bin
    if brew_bin="$(find_brew)"; then
        printf 'Homebrew found at %s\n' "$brew_bin"
        return 0
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would install Homebrew.\n'
        return 0
    fi

    printf 'Homebrew was not found; launching the official installer.\n'
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
}

install_brew_bundle() {
    local brew_bin
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would run brew bundle install --file=%s\n' "$REPO_DIR/Brewfile"
        return 0
    fi

    brew_bin="$(find_brew)" || die "Homebrew is required unless --skip-brew is used."
    eval "$("$brew_bin" shellenv)"
    "$brew_bin" bundle install --file="$REPO_DIR/Brewfile"
}

backup_target() {
    local target="$1"
    local relative destination
    relative="${target#"$HOME"/}"
    destination="$BACKUP_ROOT/$relative"

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would back up %s to %s\n' "$target" "$destination"
        return 0
    fi

    mkdir -p "$(dirname "$destination")"
    mv "$target" "$destination"
    printf 'Backed up %s to %s\n' "$target" "$destination"
}

link_config() {
    local source="$1"
    local target="$2"

    [ -e "$source" ] || die "Repository source does not exist: $source"

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        printf 'Already linked: %s\n' "$target"
        return 0
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        backup_target "$target"
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would link %s -> %s\n' "$target" "$source"
        return 0
    fi

    mkdir -p "$(dirname "$target")"
    ln -s "$source" "$target"
    printf 'Linked %s -> %s\n' "$target" "$source"
}



if [ "$SKIP_BREW" -eq 0 ]; then
    install_brew
    install_brew_bundle
else
    printf 'Skipping Homebrew setup.\n'
fi

link_config "$REPO_DIR/.zshrc" "$HOME/.zshrc"
link_config "$REPO_DIR/.zprofile" "$HOME/.zprofile"
link_config "$REPO_DIR/.bashrc" "$HOME/.bashrc"
link_config "$REPO_DIR/.bash_profile" "$HOME/.bash_profile"
link_config "$REPO_DIR/.shell_common" "$HOME/.shell_common"
link_config "$REPO_DIR/bin/1password-auth" "$HOME/.local/bin/1password-auth"

link_config "$REPO_DIR/.config/starship.toml" "$HOME/.config/starship.toml"
link_config "$REPO_DIR/.config/ghostty/config.ghostty" "$HOME/.config/ghostty/config.ghostty"

link_config "$REPO_DIR/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
link_config "$REPO_DIR/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"


fi

printf '\nDotfiles bootstrap complete.\n'
