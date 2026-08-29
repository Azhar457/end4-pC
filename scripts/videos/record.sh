#!/usr/bin/env bash

LOCAL_RECORDLY="$HOME/.local/bin/recordly"
APPIMAGE_RECORDLY="/mnt/data_d/Desktop/Apps/AppImages/Recordly-linux-x64.AppImage"

if [ -x "$LOCAL_RECORDLY" ]; then
    "$LOCAL_RECORDLY" "$@" &
elif [ -f "$APPIMAGE_RECORDLY" ]; then
    "$APPIMAGE_RECORDLY" --no-sandbox --disable-gpu-sandbox "$@" &
elif which recordly >/dev/null 2>&1; then
    recordly "$@" &
else
    notify-send "Recorder" "Recordly not found." -a 'Recorder' &
fi