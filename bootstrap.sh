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


configure_git_delta() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would configure Git to use delta for diffs.\n'
        return 0
    fi

    git config --global core.pager delta
    git config --global interactive.diffFilter 'delta --color-only'
}

apply_keyboard_replacements() {
    local source="$REPO_DIR/apps/macos/keyboard-replacements.yml"
    local database="$HOME/Library/KeyboardServices/TextReplacements.db"
    local line trigger replacement sql trigger_sql replacement_sql count=0

    [ -f "$source" ] || die "Repository source does not exist: $source"

    # ponytail: target Apple's current private store; revisit if its schema changes.
    sql='BEGIN IMMEDIATE;'
    while IFS= read -r line || [ -n "$line" ]; do
        [ -z "$line" ] || [ "${line#\#}" != "$line" ] && continue
        if [[ "$line" =~ ^\"([^\"]*)\":\ \"([^\"]*)\"$ ]]; then
            trigger="${BASH_REMATCH[1]}"
            replacement="${BASH_REMATCH[2]}"
            trigger_sql="$(printf '%s' "$trigger" | sed "s/'/''/g")"
            replacement_sql="$(printf '%s' "$replacement" | sed "s/'/''/g")"
            sql="$sql
UPDATE ZTEXTREPLACEMENTENTRY
SET ZPHRASE='$replacement_sql', ZWASDELETED=0, ZNEEDSSAVETOCLOUD=1,
    Z_OPT=Z_OPT + 1, ZTIMESTAMP=(strftime('%s','now') - 978307200)
WHERE ZSHORTCUT='$trigger_sql';
INSERT INTO ZTEXTREPLACEMENTENTRY
    (Z_PK, Z_ENT, Z_OPT, ZNEEDSSAVETOCLOUD, ZWASDELETED, ZTIMESTAMP,
     ZPHRASE, ZSHORTCUT, ZUNIQUENAME, ZREMOTERECORDINFO)
SELECT
    (SELECT COALESCE(MAX(Z_PK), 0) + 1 FROM ZTEXTREPLACEMENTENTRY), 1, 1, 1, 0,
    (strftime('%s','now') - 978307200), '$replacement_sql', '$trigger_sql',
    lower(hex(randomblob(16))), NULL
WHERE changes() = 0;"
            count=$((count + 1))
        else
            die "Unsupported replacement syntax in $source: $line"
        fi
    done < "$source"

    [ "$count" -gt 0 ] || die "No keyboard replacements found in $source"

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would apply macOS keyboard replacements from %s.\n' "$source"
        return 0
    fi

    [ -f "$database" ] || die "macOS text replacement database not found: $database"
    command -v sqlite3 >/dev/null 2>&1 || die "sqlite3 is required to update macOS text replacements."
    [ "$(sqlite3 "$database" "select 1 from sqlite_master where type='table' and name='ZTEXTREPLACEMENTENTRY';" 2>/dev/null)" = 1 ] ||
        die "Unsupported macOS text replacement database: $database"

    sql="$sql
UPDATE Z_PRIMARYKEY
SET Z_MAX=(SELECT COALESCE(MAX(Z_PK), 0) FROM ZTEXTREPLACEMENTENTRY)
WHERE Z_ENT=1;
COMMIT;"
    sqlite3 "$database" "$sql" || die "Could not update macOS text replacement database: $database"
    printf 'Applied keyboard replacements to %s\n' "$database"
}

refresh_keyboard_services() {
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would restart keyboardservicesd.\n'
        return 0
    fi

    killall keyboardservicesd 2>/dev/null || true
    launchctl kickstart -k "gui/$(id -u)/com.apple.keyboardservicesd" 2>/dev/null || true
}


if [ "$SKIP_BREW" -eq 0 ]; then
    install_brew
    install_brew_bundle
else
    printf 'Skipping Homebrew setup.\n'
fi

HOME_FILES=(
    .bash_profile
    .bashrc
    .shell_common
    .zprofile
    .zshrc
    .ssh/config
    .config/ghostty/config.ghostty
    .config/starship.toml
)

for relative_path in "${HOME_FILES[@]}"; do
    link_config "$REPO_DIR/home/$relative_path" "$HOME/$relative_path"
done

link_config "$REPO_DIR/apps/vscode/settings.json" "$HOME/Library/Application Support/Code/User/settings.json"
link_config "$REPO_DIR/apps/vscode/keybindings.json" "$HOME/Library/Application Support/Code/User/keybindings.json"
apply_keyboard_replacements
refresh_keyboard_services

configure_git_delta

fi

printf '\nDotfiles bootstrap complete.\n'
