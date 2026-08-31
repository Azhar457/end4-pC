#!/usr/bin/env bash
# list-update-backups.sh — list the pre-update backups left by the OLD
# destructive updater in ~/.config/quickshell/.backups/, so the user can
# see what the 'data hilang' looked like and pick one to recover from.
#
# These backups were created every time the in-app 'Update Dots' button
# was clicked before the safe updater landed. The old flow did:
#   mv ~/.config/quickshell/end4-pC   ~/.config/quickshell/.backups/end4-pC_<ts>
#   git clone <fork>                   ~/.config/quickshell/end4-pC
#   rm -rf                            ~/.config/quickshell/.backups/end4-pC_<ts>
# so the <ts> snapshot was a transient move-and-destroy. Any backup that
# survived is because the user aborted or the killall+restart race
# skipped the final rm -rf.
#
# The safe updater (scripts/system/update-fork.sh) no longer creates
# these; it stashes, pulls in place, and pops. This script just lets
# the user inspect the leftovers.

set -euo pipefail

BACKUP_DIR="${BACKUP_DIR:-$HOME/.config/quickshell/.backups}"

if [[ ! -d "$BACKUP_DIR" ]]; then
    printf 'No backup directory at %s\n' "$BACKUP_DIR"
    exit 0
fi

shopt -s nullglob
dirs=( "$BACKUP_DIR"/end4-pC_* )

if [[ "${#dirs[@]}" == 0 ]]; then
    printf 'No end4-pC_* backup directories in %s\n' "$BACKUP_DIR"
    exit 0
fi

printf '%-30s  %-8s  %s\n' "TIMESTAMP" "SIZE" "PATH"
for d in "${dirs[@]}"; do
    ts="$(basename "$d")"
    ts="${ts#end4-pC_}"  # strip prefix
    size="$(du -sh "$d" 2>/dev/null | awk '{print $1}')"
    printf '%-30s  %-8s  %s\n' "$ts" "$size" "$d"
done

cat <<'EOF'

To recover a specific backup's tracked files into the current tree
(keeping your present uncommitted work in a stash first):

    cd ~/.config/quickshell/end4-pC
    git stash push -u -m "before-recover-$(date +%s)"
    cp -rT ~/.config/quickshell/.backups/end4-pC_<ts>/modules .

…or cherry-pick individual files. Untracked files (the agent/,
rice-doctor, .backups-safe/, custom wallpapers) are NOT in the
backups; they live wherever you put them.
EOF
