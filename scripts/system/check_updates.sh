#!/usr/bin/env bash
# Fast update checker for Fedora (DNF5/DNF), Flatpak, and Debian/Ubuntu
pkg_count=0
if command -v dnf5 &>/dev/null; then
    pkg_count=$(dnf5 check-upgrade -q 2>/dev/null | grep -E '^[a-zA-Z0-9]' | wc -l || echo 0)
elif command -v dnf &>/dev/null; then
    pkg_count=$(dnf check-update -q 2>/dev/null | grep -E '^[a-zA-Z0-9]' | wc -l || echo 0)
elif command -v apt &>/dev/null; then
    pkg_count=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable' || echo 0)
elif command -v checkupdates &>/dev/null; then
    pacman=$(checkupdates 2>/dev/null | wc -l || echo 0)
    aur=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0)
    pkg_count=$((pacman + aur))
fi

fp_count=0
if command -v flatpak &>/dev/null; then
    fp_count=$(flatpak remote-ls --updates 2>/dev/null | wc -l || echo 0)
fi

echo $((pkg_count + fp_count))
