#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
DRY_RUN=0

usage() {
    cat <<'EOF'
Usage: platform/wsl/vscode-sync.sh {pull|push} [--dry-run]

Synchronize the common VS Code settings and WSL keybindings between this
repository and the Windows VS Code user profile used by the `code` command.
Pull imports the Windows files into apps/vscode. Push installs repository files
into Windows AppData. Replaced files are backed up under ~/.dotfiles-backups/.
EOF
}

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

ACTION="${1:-}"
case "$ACTION" in
    pull|push) shift ;;
    -h|--help|'') usage; exit 0 ;;
    *) die "Unknown action: $ACTION" ;;
esac

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
BACKUP_ROOT="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)/vscode-$ACTION"

sync_file() {
    local source="$1" target="$2" label="$3" backup
    [ -f "$source" ] || die "Repository source does not exist: $source"

    if [ -f "$target" ] && cmp -s "$source" "$target"; then
        printf 'Already synced: %s\n' "$target"
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
        printf '[dry-run] Would copy %s to %s\n' "$source" "$target"
        return 0
    fi

    mkdir -p "$(dirname -- "$target")"
    cp -- "$source" "$target"
    printf 'Copied %s -> %s\n' "$source" "$target"
}

if [ "$ACTION" = pull ]; then
    sync_file "$WINDOWS_VSCODE_DIR/settings.json" "$REPO_DIR/apps/vscode/settings.json" windows/settings.json
    sync_file "$WINDOWS_VSCODE_DIR/keybindings.json" "$REPO_DIR/apps/vscode/keybindings/wsl.json" windows/keybindings.json
else
    sync_file "$REPO_DIR/apps/vscode/settings.json" "$WINDOWS_VSCODE_DIR/settings.json" windows/settings.json
    sync_file "$REPO_DIR/apps/vscode/keybindings/wsl.json" "$WINDOWS_VSCODE_DIR/keybindings.json" windows/keybindings.json
fi
