#!/usr/bin/env bash
# install-stabilizer.sh — install and enable the end4-pC fork stabilizer.
#
# What it does:
#   1. Symlink the service + timer into ~/.config/systemd/user/
#   2. `systemctl --user daemon-reload`
#   3. `systemctl --user enable --now stabilize-fork.timer`
#   4. Verify the timer is active.
#
# Run once:  bash scripts/system/install-stabilizer.sh
# To uninstall: bash scripts/system/uninstall-stabilizer.sh

set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/.config/quickshell/end4-pC}"
SRC_DIR="$REPO_DIR/scripts/system"
DST_DIR="$HOME/.config/systemd/user"

mkdir -p "$DST_DIR"

for f in stabilize-fork.service stabilize-fork.timer; do
    if [[ ! -f "$SRC_DIR/$f" ]]; then
        printf '[install-stabilizer] missing source %s — aborting\n' "$SRC_DIR/$f" >&2
        exit 1
    fi
    ln -sf "$SRC_DIR/$f" "$DST_DIR/$f"
    printf '[install-stabilizer] linked %s -> %s\n' "$DST_DIR/$f" "$SRC_DIR/$f"
done

systemctl --user daemon-reload
systemctl --user enable --now stabilize-fork.timer

if systemctl --user is-active --quiet stabilize-fork.timer; then
    printf '[install-stabilizer] stabilize-fork.timer is ACTIVE.\n'
else
    printf '[install-stabilizer] WARNING: stabilize-fork.timer did not start. Check `systemctl --user status stabilize-fork.timer`.\n' >&2
    exit 1
fi

printf '\nThe stabilizer now runs every 30 seconds and restores any\n'
printf 'tracked file in %s that has drifted from HEAD (e.g. reverted\n' "$REPO_DIR"
printf 'by an AI coding agent). Untracked files are NEVER touched.\n'
printf '\nVerify:  systemctl --user list-timers | grep stabilize-fork\n'
printf 'Disable: systemctl --user disable --now stabilize-fork.timer\n'
printf 'Manual:  bash %s/stabilize-fork.sh\n' "$SRC_DIR"
