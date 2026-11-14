#!/usr/bin/env bash

# Apply the repository's text replacements to Apple's local database.
set -Eeuo pipefail

REPO_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd -P)"
DRY_RUN=0
ACTION=apply

usage() {
    printf 'Usage: %s [--dry-run] [apply|refresh]\n' "$0"
}

while [ "$#" -gt 0 ]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        -h|--help) usage; exit 0 ;;
        apply|refresh) ACTION="$1" ;;
        *) printf 'Error: unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
    esac
    shift
done

die() {
    printf 'Error: %s\n' "$1" >&2
    exit 1
}

if [ "$ACTION" = refresh ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        printf '[dry-run] Would restart keyboardservicesd.\n'
    else
        killall keyboardservicesd 2>/dev/null || true
        launchctl kickstart -k "gui/$(id -u)/com.apple.keyboardservicesd" 2>/dev/null || true
    fi
    exit 0
fi

source="$REPO_DIR/platform/osx/keyboard-replacements.yml"
database="$HOME/Library/KeyboardServices/TextReplacements.db"
line=''
trigger=''
replacement=''
sql=''
trigger_sql=''
replacement_sql=''
count=0

[ -f "$source" ] || die "Repository source does not exist: $source"

# The file intentionally uses the small quoted key/value subset parsed here.
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
    exit 0
fi

[ -f "$database" ] || die "macOS text replacement database not found: $database"
command -v sqlite3 >/dev/null 2>&1 || die 'sqlite3 is required to update macOS text replacements.'
[ "$(sqlite3 "$database" "select 1 from sqlite_master where type='table' and name='ZTEXTREPLACEMENTENTRY';" 2>/dev/null)" = 1 ] ||
    die "Unsupported macOS text replacement database: $database"

sql="$sql
UPDATE Z_PRIMARYKEY
SET Z_MAX=(SELECT COALESCE(MAX(Z_PK), 0) FROM ZTEXTREPLACEMENTENTRY)
WHERE Z_ENT=1;
COMMIT;"
sqlite3 "$database" "$sql" || die "Could not update macOS text replacement database: $database"
printf 'Applied keyboard replacements to %s\n' "$database"
