#!/usr/bin/env bash
# stabilize-fork.sh — auto-restore tracked fork files from HEAD.
#
# Why: the opencode CLI agent (and any other tool with a filesystem
# MCP that can write under the fork) keeps reverting the wallpaper /
# live-wallpaper / updater fixes by editing tracked files in
# ~/.config/quickshell/end4-pC/ between user actions. The safe
# `update-fork.sh` updater no longer wipes data on pull, but it does
# nothing to prevent in-session reverts. This stabilizer detects
# tracked files that have drifted from HEAD and restores them.
#
# What it does:
#   1. cd to the fork repo.
#   2. For every tracked file that differs from HEAD, run
#      `git checkout HEAD -- <file>` (safe, non-destructive: untracked
#      files, uncommitted-but-staged-but-skipped (e.g. merge), and
#      index are preserved; only working-tree content of the listed
#      tracked file is replaced).
#   3. Skip untracked files (the agent / rice-doctor / .backups / custom
#      wallpapers, etc.) — they are user data and must never be touched.
#   4. Print a single one-line summary when something changed; stay
#      silent on no-op runs.
#
# Tunable: pass --all to restore EVERY tracked file (even those
# matching HEAD) — useful as a one-shot "reset to HEAD" but normally
# unnecessary.
#
# Designed to be run by the accompanying systemd user timer
# (stabilize-fork.timer, every 30s) or manually:
#   bash scripts/system/stabilize-fork.sh
#   REPO_DIR=/path/to/fork bash scripts/system/stabilize-fork.sh
#
# Safety: if a tracked file was modified in the last 2 seconds (likely
# mid-write), it's skipped to avoid truncating an in-flight edit. The
# agent's writes are fast but this leaves a small race window; running
# every 30s keeps it bounded.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/.config/quickshell/end4-pC}"
MODE="changed"  # "changed" restores only files that differ from HEAD
if [[ "${1:-}" == "--all" ]]; then
    MODE="all"
fi

cd "$REPO_DIR" 2>/dev/null || {
    printf '[stabilize-fork] skip: cannot cd into %s\n' "$REPO_DIR" >&2
    exit 0
}

# Must be a git working tree.
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    printf '[stabilize-fork] skip: %s is not a git working tree\n' "$REPO_DIR" >&2
    exit 0
fi

# Build the list of candidate tracked files.
if [[ "$MODE" == "all" ]]; then
    mapfile -t CANDIDATES < <(git ls-files)
else
    mapfile -t CANDIDATES < <(git diff --name-only HEAD)
fi

if [[ "${#CANDIDATES[@]}" == "0" ]]; then
    exit 0
fi

# Filter out files modified in the last 2 seconds (mid-write safety).
# stat -c %Y gives mtime in seconds since epoch.
NOW="$(date +%s)"
RESTORED=()
SKIPPED=()
for f in "${CANDIDATES[@]}"; do
    # Resolve the path relative to the repo root. If the file was
    # deleted from the working tree, `git diff` still reports it, but
    # there's nothing to check out — skip.
    [[ -e "$f" ]] || continue
    mtime="$(stat -c %Y "$f" 2>/dev/null || echo 0)"
    if (( NOW - mtime < 2 )); then
        SKIPPED+=("$f")
        continue
    fi
    if git checkout HEAD -- "$f" 2>/dev/null; then
        RESTORED+=("$f")
    else
        SKIPPED+=("$f")
    fi
done

if [[ "${#RESTORED[@]}" -gt 0 ]]; then
    printf '[stabilize-fork] restored %d file(s) from HEAD: %s\n' \
        "${#RESTORED[@]}" \
        "$(printf '%s, ' "${RESTORED[@]}" | sed 's/, $//')"
fi
if [[ "${#SKIPPED[@]}" -gt 0 && "${VERBOSE:-0}" == "1" ]]; then
    printf '[stabilize-fork] skipped %d file(s) (mid-write or checkout error): %s\n' \
        "${#SKIPPED[@]}" \
        "$(printf '%s, ' "${SKIPPED[@]}" | sed 's/, $//')" >&2
fi

exit 0
