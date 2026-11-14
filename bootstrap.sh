#!/usr/bin/env bash

# Run this file from a terminal with `./bootstrap.sh`; do not source it.
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DRY_RUN=0
SKIP_BREW=0
SKIP_APT=0

usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [options]

Install packages and symlink the repository configs on macOS, Ubuntu, or WSL.
Ubuntu uses apt for system prerequisites and Docker Engine. WSL uses apt for
Linux prerequisites and Docker Desktop integration, without installing Docker
Engine or enabling a Docker service. Homebrew installs common terminal tools.

Options:
  --dry-run    Show actions without changing the machine.
  --skip-brew  Skip Homebrew installation and Brewfile processing.
  --skip-apt   Skip Ubuntu/WSL system setup.
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
        --skip-apt) SKIP_APT=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

case "$(uname -s)" in
    Darwin) PLATFORM=osx ;;
    Linux)
        [ -r /etc/os-release ] || die 'Cannot identify this Linux distribution.'
        . /etc/os-release
        [ "${ID:-}" = ubuntu ] || die 'This bootstrap supports macOS and Ubuntu/WSL only.'
        if [ -n "${WSL_DISTRO_NAME:-}" ] || grep -qi microsoft /proc/version; then
            PLATFORM=wsl
        else
            PLATFORM=ubuntu
        fi
        ;;
    *) die 'This bootstrap supports macOS and Ubuntu/WSL only.' ;;
esac
[ -d "$HOME" ] || die 'HOME is not set to a valid directory.'

BACKUP_ROOT="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

run_platform_setup() {
    local script="$REPO_DIR/platform/$PLATFORM/setup.sh"
    local -a arguments=()
    [ -x "$script" ] || die "Platform setup script is missing or not executable: $script"
    if [ "$DRY_RUN" -eq 1 ]; then
        arguments+=(--dry-run)
    fi
    "$script" "${arguments[@]}"
}

find_brew() {
    local candidate
    candidate="$(command -v brew 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    for candidate in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
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
        if [ "$PLATFORM" = osx ]; then
            printf '[dry-run] Would run brew bundle install --file=%s\n' "$REPO_DIR/platform/osx/Brewfile"
        fi
        return 0
    fi
    brew_bin="$(find_brew)" || die 'Homebrew is required unless --skip-brew is used.'
    eval "$("$brew_bin" shellenv)"
    "$brew_bin" bundle install --file="$REPO_DIR/Brewfile"
    if [ "$PLATFORM" = osx ]; then
        "$brew_bin" bundle install --file="$REPO_DIR/platform/osx/Brewfile"
    fi
}

ensure_codex_plugin() {
    local source="$1" marketplace="$2" plugin="$3" marketplaces installed
    marketplaces="$(codex plugin marketplace list --json)"
    if ! printf '%s\n' "$marketplaces" | grep -Fq "\"name\": \"$marketplace\""; then
        codex plugin marketplace add "$source"
    fi
    installed="$(codex plugin list --json)"
    if ! printf '%s\n' "$installed" | grep -Fq "\"name\": \"$plugin\"" \
        || ! printf '%s\n' "$installed" | grep -Fq "\"marketplaceName\": \"$marketplace\""; then
        codex plugin add "$plugin@$marketplace"
    fi
}

install_codex_skills() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would install Ponytail and Matt Pocock Codex plugins if the Codex CLI is available.\n'
        return 0
    fi
    if ! command -v codex >/dev/null 2>&1; then
        printf 'Codex CLI not found; install Codex and rerun bootstrap to install Ponytail and Matt Pocock skills.\n'
        return 0
    fi
    ensure_codex_plugin DietrichGebert/ponytail ponytail ponytail
    ensure_codex_plugin mattpocock/skills mattpocock mattpocock-skills
}

install_vscode_extensions() {
    local extension installed
    local extensions=(
        PKief.material-icon-theme
        OpenAI.chatgpt
        ms-toolsai.jupyter
        detachhead.basedpyright
        ms-python.python
    )
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would install VS Code extensions if the code CLI is available: %s\n' "${extensions[*]}"
        return 0
    fi
    if ! command -v code >/dev/null 2>&1; then
        printf 'VS Code CLI not found; install VS Code and rerun bootstrap to install its configured extensions.\n'
        return 0
    fi
    installed="$(code --list-extensions)"
    for extension in "${extensions[@]}"; do
        if ! printf '%s\n' "$installed" | grep -Fxiq "$extension"; then
            code --install-extension "$extension"
        fi
    done
}

backup_target() {
    local target="$1" relative destination
    if [[ "$target" == "$HOME/"* ]]; then
        relative="${target#"$HOME"/}"
    else
        relative="external/${target#/}"
    fi
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
    local source="$1" target="$2"
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

configure_vscode() {
    local vscode_dir keybinding_source
    case "$PLATFORM" in
        osx) vscode_dir="$HOME/Library/Application Support/Code/User" ;;
        ubuntu) vscode_dir="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User" ;;
        wsl)
            local -a arguments=(push)
            if [ "$DRY_RUN" -eq 1 ]; then
                arguments+=(--dry-run)
            fi
            "$REPO_DIR/platform/wsl/vscode-sync.sh" "${arguments[@]}"
            install_vscode_extensions
            return
            ;;
    esac
    keybinding_source="$REPO_DIR/apps/vscode/keybindings/$PLATFORM.json"
    link_config "$REPO_DIR/apps/vscode/settings.json" "$vscode_dir/settings.json"
    link_config "$keybinding_source" "$vscode_dir/keybindings.json"
}

configure_git_delta() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would configure Git to use delta for diffs.\n'
        return 0
    fi
    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
}

configure_git_identity() {
    local git_email
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would set the global Git name to wglazer and prompt for an email if one is not configured.\n'
        return 0
    fi
    git config --global user.name wglazer
    if git config --global --get user.email >/dev/null 2>&1; then
        return 0
    fi
    [ -t 0 ] || die 'Git user.email is not configured; rerun bootstrap in an interactive terminal to enter it.'
    while true; do
        read -r -p 'Git email for this machine: ' git_email || die 'Could not read the Git email.'
        [ -n "$git_email" ] && break
        printf 'Git email cannot be empty.\n' >&2
    done
    git config --global user.email "$git_email"
}

remove_legacy_gpg_wrapper() {
    local target="$HOME/.local/bin/gpg1pass"
    local source="$REPO_DIR/home/.local/bin/gpg1pass"
    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        backup_target "$target"
    fi
}

case "$PLATFORM" in
    ubuntu|wsl)
        if [ "$SKIP_APT" -eq 0 ]; then
            run_platform_setup
        else
            printf 'Skipping %s system setup.\n' "$PLATFORM"
        fi
        ;;
    osx) ;;
esac

if [ "$SKIP_BREW" -eq 0 ]; then
    install_brew
    install_brew_bundle
else
    printf 'Skipping Homebrew setup.\n'
fi

HOME_FILES=(
    .bash_profile .bashrc .shell_common .zprofile .zshrc
    .config/ghostty/config.ghostty .config/starship.toml
    .codex/config.toml .codex/AGENTS.md .codex/hooks.json
    .codex/hooks/turn-diff.js .codex/skills/software-design-philosophy
    .codex/shell.sh .local/bin/turn-diff .local/bin/dotfiles-alias
)
for relative_path in "${HOME_FILES[@]}"; do
    link_config "$REPO_DIR/home/$relative_path" "$HOME/$relative_path"
done

LOCAL_BIN_ALIASES=(ls l ll la lt td cat grep g gs gd gl lg v vim zj)
for alias in "${LOCAL_BIN_ALIASES[@]}"; do
    link_config "$REPO_DIR/home/.local/bin/dotfiles-alias" "$HOME/.local/bin/$alias"
done

install_codex_skills
configure_vscode

if [ "$PLATFORM" = osx ]; then
    local_script="$REPO_DIR/platform/osx/setup.sh"
    arguments=()
    if [ "$DRY_RUN" -eq 1 ]; then
        arguments+=(--dry-run)
    fi
    "$local_script" "${arguments[@]}"
fi

configure_git_identity
configure_git_delta
remove_legacy_gpg_wrapper

printf '\nDotfiles bootstrap complete.\n'
