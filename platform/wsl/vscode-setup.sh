#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: platform/wsl/vscode-setup.sh [--dry-run]

Install the repository's VS Code settings and keybindings into the
Windows VS Code user profile. Replaced files are backed up under
~/.dotfiles-backups/.
EOF
}

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

windows_vscode_user_dir() {
    local appdata
    command -v powershell.exe >/dev/null 2>&1 || die "powershell.exe is required to locate Windows AppData."
    command -v wslpath >/dev/null 2>&1 || die "wslpath is required to locate Windows AppData."
    appdata="$(powershell.exe -NoProfile -NonInteractive -Command '[Environment]::GetFolderPath("ApplicationData")' | tr -d '\r')"
    [ -n "$appdata" ] || die "Could not read the Windows AppData path."
    wslpath -u "$appdata/Code/User"
}

WINDOWS_VSCODE_DIR="$(windows_vscode_user_dir)"
BACKUP_ROOT="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)/vscode"

install_file() {
    local source="$1" target="$2" label="$3" backup
    [ -f "$source" ] || die "Repository source does not exist: $source"

    if [ -f "$target" ] && cmp -s "$source" "$target"; then
        printf 'Already configured: %s\n' "$target"
        return 0
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        backup="$BACKUP_ROOT/$label"
        if [ "$DRY_RUN" -eq 1 ]; then
            printf '[dry-run] Would back up %s to %s\n' "$target" "$backup"
        else
            mkdir -p "$(dirname -- "$backup")"
            mv -- "$target" "$backup"
            printf 'Backed up %s to %s\n' "$target" "$backup"
        fi
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would install %s at %s\n' "$source" "$target"
        return 0
    fi

    mkdir -p "$(dirname -- "$target")"
    cp -- "$source" "$target"
    printf 'Installed %s -> %s\n' "$source" "$target"
}

install_file "$REPO_DIR/apps/vscode/settings.json" "$WINDOWS_VSCODE_DIR/settings.json" windows/settings.json
install_file "$REPO_DIR/apps/vscode/keybindings.json" "$WINDOWS_VSCODE_DIR/keybindings.json" windows/keybindings.json
