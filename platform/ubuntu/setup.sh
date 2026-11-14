#!/usr/bin/env bash

# Install Ubuntu system prerequisites and Docker Engine. Homebrew packages are
# managed separately by the repository's shared Brewfile.
set -Eeuo pipefail

DRY_RUN=0
SKIP_DOCKER=0
for argument in "$@"; do
    case "$argument" in
        --dry-run) DRY_RUN=1 ;;
        --skip-docker) SKIP_DOCKER=1 ;;
        -h|--help)
            printf 'Usage: %s [--dry-run] [--skip-docker]\n' "$0"
            exit 0
            ;;
        *) printf 'Error: unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

find_brew() {
    local candidate
    candidate="$(command -v brew 2>/dev/null || true)"
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then
        printf '%s\n' "$candidate"
        return 0
    fi
    for candidate in /home/linuxbrew/.linuxbrew/bin/brew "$HOME/.linuxbrew/bin/brew"; do
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

check_docker_conflicts() {
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
        die 'Both docker-ce and docker.io are installed. Resolve the Docker package conflict before continuing.'
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
        command -v sudo >/dev/null 2>&1 || die 'sudo is required for Ubuntu system setup.'
        sudo "$@"
    fi
}

install_system() {
    local docker_packages source
    local prerequisites=(build-essential procps curl file git ca-certificates zsh nodejs npm xclip fonts-jetbrains-mono)
    if [ "$SKIP_DOCKER" -eq 1 ]; then
        docker_packages=()
    elif apt_package_installed docker.io; then
        docker_packages=(docker.io docker-compose-v2 docker-buildx)
    else
        docker_packages=(docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    fi

    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would run apt-get update and apt-get install -y %s\n' "${prerequisites[*]}"
        if [ "$SKIP_DOCKER" -eq 0 ] && ! apt_package_installed docker-ce && ! apt_package_installed docker.io; then
            printf '[dry-run] Would configure Docker official Ubuntu apt repository and signing key.\n'
        fi
        if [ "$SKIP_DOCKER" -eq 0 ]; then
            printf '[dry-run] Would ensure apt packages: %s\n' "${docker_packages[*]}"
            printf '[dry-run] Would enable and start Docker if systemd is running.\n'
        fi
        return 0
    fi

    run_apt apt-get update
    run_apt apt-get install -y "${prerequisites[@]}"
    if [ "$SKIP_DOCKER" -eq 0 ] && ! apt_package_installed docker-ce && ! apt_package_installed docker.io; then
        [ -n "${VERSION_CODENAME:-}" ] || die 'Ubuntu VERSION_CODENAME is missing.'
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
    if [ "$SKIP_DOCKER" -eq 1 ]; then
        return 0
    fi
    run_apt apt-get install -y --no-upgrade "${docker_packages[@]}"
    if [ -d /run/systemd/system ] && command -v systemctl >/dev/null 2>&1 && systemctl show --property=Version --value >/dev/null 2>&1; then
        run_apt systemctl enable --now docker.service
    else
        printf 'Docker packages are installed; systemd is not running. Start Docker manually on the host.\n'
    fi
}

if [ "$SKIP_DOCKER" -eq 0 ]; then
    check_docker_conflicts
fi
install_system
