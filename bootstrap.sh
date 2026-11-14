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
SKIP_APT=0
GIT_SIGNING_KEY="${DOTFILES_GIT_SIGNING_KEY:-$HOME/.ssh/github_signing.pub}"

usage() {
    cat <<'EOF'
Usage: ./bootstrap.sh [options]

Install packages and symlink the repository configs on macOS or Ubuntu.
Ubuntu uses apt for build prerequisites and native Docker, and Homebrew for
terminal tools. macOS uses Homebrew formulae and application casks.

The script finds this repository automatically, so it can be run from any
directory. Existing files are backed up before they are replaced.

Options:
  --dry-run    Show the actions without changing the machine.
  --skip-brew  Skip Homebrew installation and Brewfile processing.
  --skip-apt   Skip Ubuntu prerequisites, Docker installation, and service setup.
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
    Darwin) PLATFORM=macos ;;
    Linux)
        [ -r /etc/os-release ] || die "Cannot identify this Linux distribution."
        . /etc/os-release
        [ "${ID:-}" = ubuntu ] || die "This bootstrap supports macOS and Ubuntu only."
        PLATFORM=ubuntu
        ;;
    *) die "This bootstrap supports macOS and Ubuntu only." ;;
esac
[ -d "$HOME" ] || die "HOME is not set to a valid directory."

BACKUP_ROOT="$HOME/.dotfiles-backups/$(date +%Y%m%d-%H%M%S)"

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

apt_package_installed() {
    [ "$(dpkg-query -W -f='${Status}' "$1" 2>/dev/null || true)" = 'install ok installed' ]
}

check_ubuntu_docker() {
    local brew_bin installed formula duplicates='' docker_bin
    if brew_bin="$(find_brew)"; then
        installed="$("$brew_bin" list --formula)"
        for formula in docker docker-compose docker-buildx; do
            if [[ $'\n'"$installed"$'\n' == *$'\n'"$formula"$'\n'* ]]; then
                duplicates="$duplicates $formula"
            fi
        done
        if [ -n "$duplicates" ]; then
            if [ "$DRY_RUN" -eq 1 ]; then
                printf '[dry-run] Docker duplicates must be removed before a real run: brew uninstall%s\n' "$duplicates"
            else
                die "Ubuntu Docker must be managed by apt. After verifying apt replacements, run: brew uninstall$duplicates"
            fi
        fi
    fi

    if apt_package_installed docker-ce && apt_package_installed docker.io; then
        die "Both docker-ce and docker.io are installed. Resolve the Docker package conflict before continuing."
    fi
    if ! apt_package_installed docker-ce && ! apt_package_installed docker.io; then
        docker_bin="$(command -v docker 2>/dev/null || true)"
        if [ -n "$docker_bin" ]; then
            die "Docker at $docker_bin is not backed by an apt-managed Engine. Resolve the existing installation before continuing."
        fi
        for formula in docker-ce-cli docker-compose docker-compose-v2 docker-doc docker-buildx podman-docker containerd containerd.io runc; do
            if apt_package_installed "$formula"; then
                die "Existing package $formula may conflict with Docker Engine installation. Resolve it before continuing."
            fi
        done
    fi
}

run_apt() {
    if [ "$(id -u)" -eq 0 ]; then
        "$@"
    else
        command -v sudo >/dev/null 2>&1 || die "sudo is required for Ubuntu system setup."
        sudo "$@"
    fi
}

install_ubuntu_system() {
    local docker_packages source
    local prerequisites=(build-essential procps curl file git ca-certificates)
    if apt_package_installed docker.io; then
        docker_packages=(docker.io docker-compose-v2 docker-buildx)
    else
        docker_packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would run apt-get update and apt-get install -y %s\n' "${prerequisites[*]}"
        if ! apt_package_installed docker-ce && ! apt_package_installed docker.io; then
            printf '[dry-run] Would configure Docker official Ubuntu apt repository and signing key.\n'
        fi
        printf '[dry-run] Would ensure apt packages: %s\n' "${docker_packages[*]}"
        printf '[dry-run] Would enable and start Docker if systemd is running.\n'
        return 0
    fi

    run_apt apt-get update
    run_apt apt-get install -y "${prerequisites[@]}"
    if ! apt_package_installed docker-ce && ! apt_package_installed docker.io; then
        [ -n "${VERSION_CODENAME:-}" ] || die "Ubuntu VERSION_CODENAME is missing."
        run_apt install -m 0755 -d /etc/apt/keyrings
        run_apt curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        run_apt chmod a+r /etc/apt/keyrings/docker.asc
        source="Types: deb
URIs: https://download.docker.com/linux/ubuntu
Suites: $VERSION_CODENAME
Components: stable
Architectures: $(dpkg --print-architecture)
Signed-By: /etc/apt/keyrings/docker.asc"
        printf '%s\n' "$source" | run_apt tee /etc/apt/sources.list.d/docker.sources >/dev/null
        run_apt apt-get update
    fi
    # Keep the installed provider and avoid upgrading an existing Engine.
    run_apt apt-get install -y --no-upgrade "${docker_packages[@]}"
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1 && systemctl show --property=Version --value >/dev/null 2>&1; then
        run_apt systemctl enable --now docker.service
    else
        printf 'Docker packages are installed; systemd is not running. Start Docker manually on the host.\n'
    fi
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

ensure_codex_plugin() {
    local source="$1"
    local marketplace="$2"
    local plugin="$3"
    local marketplaces installed

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

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would configure Git to sign with SSH key %s\n' "$GIT_SIGNING_KEY"
        return 0
    fi

    git config --global commit.gpgsign true
    git config --global gpg.format ssh
    git config --global user.signingkey "$GIT_SIGNING_KEY"
    git config --global --unset-all gpg.program || true
    if [ ! -f "$GIT_SIGNING_KEY" ]; then
        printf 'SSH signing public key not found at %s; add it before signing commits.\n' "$GIT_SIGNING_KEY" >&2
    fi
}

remove_legacy_gpg_wrapper() {

    if [ -L "$target" ] && [ "$(readlink "$target")" = "$source" ]; then
        backup_target "$target"
    fi
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

if [ "$PLATFORM" = ubuntu ]; then
    if [ "$SKIP_APT" -eq 0 ] || [ "$SKIP_BREW" -eq 0 ]; then
        check_ubuntu_docker
    fi
    if [ "$SKIP_APT" -eq 0 ]; then
        install_ubuntu_system
    else
        printf 'Skipping Ubuntu system setup.\n'
    fi
fi

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
    .codex/config.toml
    .codex/AGENTS.md
    .codex/hooks.json
    .codex/hooks/turn-diff.js
    .codex/skills/software-design-philosophy
    .codex/shell.sh
    .local/bin/turn-diff
    .local/bin/dotfiles-alias
)

for relative_path in "${HOME_FILES[@]}"; do
    link_config "$REPO_DIR/home/$relative_path" "$HOME/$relative_path"
done

LOCAL_BIN_ALIASES=(ls l ll la lt td cat grep g gs gd gl lg v vim zj)
for alias in "${LOCAL_BIN_ALIASES[@]}"; do
    link_config "$REPO_DIR/home/.local/bin/dotfiles-alias" "$HOME/.local/bin/$alias"
done

install_codex_skills

if [ "$PLATFORM" = macos ]; then
    VSCODE_DIR="$HOME/Library/Application Support/Code/User"
else
    VSCODE_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/Code/User"
fi
link_config "$REPO_DIR/apps/vscode/settings.json" "$VSCODE_DIR/settings.json"
link_config "$REPO_DIR/apps/vscode/keybindings.json" "$VSCODE_DIR/keybindings.json"
if [ "$PLATFORM" = macos ]; then
    apply_keyboard_replacements
    refresh_keyboard_services
fi

configure_git_delta
remove_legacy_gpg_wrapper

printf '\nDotfiles bootstrap complete.\n'
