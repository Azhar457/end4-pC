#!/usr/bin/env bash
# uninstall-stabilizer.sh — stop and remove the end4-pC fork stabilizer.

set -euo pipefail

systemctl --user disable --now stabilize-fork.timer 2>/dev/null || true
rm -f "$HOME/.config/systemd/user/stabilize-fork.service" \
      "$HOME/.config/systemd/user/stabilize-fork.timer"
systemctl --user daemon-reload || true
printf '[uninstall-stabilizer] removed.\n'
