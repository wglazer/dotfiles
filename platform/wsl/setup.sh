#!/usr/bin/env bash

# Install Linux-side prerequisites for WSL. Docker is provided by Docker
# Desktop on Windows, so this intentionally skips Linux Engine checks/setup.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DRY_RUN=0
arguments=(--skip-docker)
for argument in "$@"; do
    case "$argument" in
        --dry-run) DRY_RUN=1; arguments+=(--dry-run) ;;
        -h|--help)
            printf 'Usage: %s [--dry-run]\n' "$0"
            exit 0
            ;;
        *) printf 'Error: unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done

"$SCRIPT_DIR/../ubuntu/setup.sh" "${arguments[@]}"

if [ "$DRY_RUN" -eq 1 ]; then
    printf '[dry-run] Would check for the Docker CLI provided by Docker Desktop WSL integration.\n'
elif command -v docker >/dev/null 2>&1; then
    printf 'Docker Desktop CLI is available in WSL.\n'
else
    printf 'Docker CLI is unavailable. Enable this distro under Docker Desktop Settings > Resources > WSL Integration.\n'
fi
