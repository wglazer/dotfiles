#!/usr/bin/env bash

# Apply managed text replacements and refresh Apple's keyboard service.
set -Eeuo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
DRY_RUN=0
for argument in "$@"; do
    case "$argument" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help)
            printf 'Usage: %s [--dry-run]\n' "$0"
            exit 0
            ;;
        *) printf 'Error: unknown option: %s\n' "$argument" >&2; exit 2 ;;
    esac
done

dry_run_args=()
if [ "$DRY_RUN" -eq 1 ]; then
    dry_run_args=(--dry-run)
fi

"$SCRIPT_DIR/keyboard-replacements.sh" "${dry_run_args[@]}"
"$SCRIPT_DIR/keyboard-replacements.sh" "${dry_run_args[@]}" refresh
