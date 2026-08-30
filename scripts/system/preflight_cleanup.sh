#!/usr/bin/env bash
# Preflight System Healing & Cleanup Script for end4-pC
# Cleans dead PID singleton locks, verifies XEmbed bridge, and ensures core daemons are healthy.

set -euo pipefail

# 1. Clean Stale Electron / App Singleton Locks
clean_stale_locks() {
    local config_dir="${XDG_CONFIG_HOME:-$HOME/.config}"
    find "$config_dir" -maxdepth 2 -name "SingletonLock" 2>/dev/null | while read -r lock_file; do
        if [ -L "$lock_file" ]; then
            local target
            target="$(readlink "$lock_file" || true)"
            local pid="${target##*-}"
            if [ -n "$pid" ] && [[ "$pid" =~ ^[0-9]+$ ]]; then
                if ! kill -0 "$pid" 2>/dev/null; then
                    local app_dir
                    app_dir="$(dirname "$lock_file")"
                    rm -f "$app_dir"/Singleton* 2>/dev/null || true
                fi
            fi
        fi
    done
}

# 2. Ensure xembedsniproxy is running (bridges X11/XWayland tray to D-Bus SNI)
ensure_xembed_bridge() {
    if command -v xembedsniproxy >/dev/null 2>&1; then
        if ! pgrep -x xembedsniproxy >/dev/null 2>&1; then
            nohup xembedsniproxy >/dev/null 2>&1 &
        fi
    fi
}

# 3. Ensure Hermes Rice Proxy is running
ensure_hermes_proxy() {
    if command -v systemctl >/dev/null 2>&1; then
        if systemctl --user is-enabled hermes-rice-proxy.service >/dev/null 2>&1; then
            if ! systemctl --user is-active hermes-rice-proxy.service >/dev/null 2>&1; then
                systemctl --user start hermes-rice-proxy.service 2>/dev/null || true
            fi
        fi
    fi
}

clean_stale_locks
ensure_xembed_bridge
ensure_hermes_proxy

exit 0
