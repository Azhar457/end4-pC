#!/usr/bin/env bash
# record.sh — start a screen recording.
#
# Restored to the upstream end-4 lightweight default: `wf-recorder`,
# the Hyprland-native screen recorder. The fork at a7151d5 used
# `recordly` (a heavier AppImage) which is heavier to run and to keep
# on disk, and not a general-purpose recorder. The end-4 default is
# `wf-recorder` (with optional `-g` for the focused output). This
# fork's stability and lightweight goals are best served by the
# upstream default.

if command -v wf-recorder >/dev/null 2>&1; then
    exec wf-recorder "$@"
elif command -v wl-screenrec >/dev/null 2>&1; then
    exec wl-screenrec "$@"
else
    notify-send "Recorder" "No screen recorder (wf-recorder / wl-screenrec) found." -a 'Recorder' || true
    exit 1
fi
