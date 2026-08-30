#!/usr/bin/env bash
# Fast update checker for Fedora (DNF5/DNF), Flatpak, and Debian/Ubuntu
# Emits three lines:
#   system=N   flatpak=N   total=N

# --- DNF / APT / pacman: only count real package-update lines, not metadata ---
sys_count=0
if command -v dnf5 &>/dev/null; then
    sys_count=$(dnf5 check-upgrade 2>/dev/null \
        | grep -E '\.(x86_64|noarch|i686|aarch64|src|ppc64le|s390x)[[:space:]]+[0-9]' \
        | wc -l)
elif command -v dnf &>/dev/null; then
    sys_count=$(dnf check-update 2>/dev/null \
        | grep -E '\.(x86_64|noarch|i686|aarch64|src|ppc64le|s390x)[[:space:]]+[0-9]' \
        | wc -l)
elif command -v apt &>/dev/null; then
    sys_count=$(apt list --upgradable 2>/dev/null | grep -c 'upgradable' || echo 0)
elif command -v checkupdates &>/dev/null; then
    pacman=$(checkupdates 2>/dev/null | wc -l || echo 0)
    aur=$(yay -Qua 2>/dev/null | wc -l || paru -Qua 2>/dev/null | wc -l || echo 0)
    sys_count=$((pacman + aur))
fi
sys_count=${sys_count:-0}

# --- Flatpak: parse one entry per non-empty line that contains a tab (real rows) ---
fp_count=0
if command -v flatpak &>/dev/null; then
    fp_count=$(flatpak remote-ls --updates 2>/dev/null | awk -F'\t' 'NF >= 4 {c++} END {print c+0}')
fi
fp_count=${fp_count:-0}

total=$((sys_count + fp_count))
printf 'system=%d\nflatpak=%d\ntotal=%d\n' "$sys_count" "$fp_count" "$total"
