#!/usr/bin/env bash
# stabilize-fork-watch.sh — fallback for hosts without a working
# `systemctl --user`. Polls scripts/system/stabilize-fork.sh every
# STABILIZE_INTERVAL seconds in a foreground loop. Run in a terminal
# multiplexer (tmux/screen), or background it:
#   nohup bash scripts/system/stabilize-fork-watch.sh >/dev/null 2>&1 &
# Stop with: pkill -f stabilize-fork-watch.sh

set -euo pipefail

INTERVAL="${STABILIZE_INTERVAL:-30}"

cd "${REPO_DIR:-$HOME/.config/quickshell/end4-pC}"

while true; do
    bash "$REPO_DIR/scripts/system/stabilize-fork.sh" || true
    sleep "$INTERVAL"
done
