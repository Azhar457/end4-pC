#!/usr/bin/env bash
# update-fork.sh — safe, in-place update of the end4-pC fork.
#
# Replaces the previous destructive "git clone + rm -rf" updater in
# modules/ii/settings/pages/About.qml. That updater moved the user's
# working tree to end4-pC-old, cloned fresh, and then DELETED end4-pC-old
# — silently destroying every uncommitted edit, untracked file
# (agent/, rice-doctor, SafeWidgetLoader, LiveWallpaper, FeatureRegistry,
#  custom wallpapers, wallpaperPath config, AI agent sessions, etc.)
# and every unpushed local commit.
#
# This script preserves ALL of that by:
#   1. stashing uncommitted + untracked work
#   2. fetching origin
#   3. fast-forwarding or rebasing the local branch on top of the remote
#   4. popping the stash to restore uncommitted + untracked files
# Aborts cleanly on conflict and leaves the stash in place for manual
# recovery. Never deletes the user's working tree.

set -euo pipefail

REPO_DIR="${REPO_DIR:-$HOME/.config/quickshell/end4-pC}"
TS="$(date +%Y%m%d_%H%M%S)"
STASH_MSG="safe-update-${TS}"

log() { printf '[update-fork] %s\n' "$*"; }
die() { printf '[update-fork] ERROR: %s\n' "$*" >&2; exit 1; }

cd "$REPO_DIR" || die "Cannot cd into $REPO_DIR (is the fork installed at $REPO_DIR?)"

# Pre-flight
git rev-parse --is-inside-work-tree >/dev/null 2>&1 \
    || die "$REPO_DIR is not a git working tree"
git remote get-url origin >/dev/null 2>&1 \
    || die "No 'origin' remote configured. Update manually with git."

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
log "Repo:        $REPO_DIR"
log "Branch:      $CURRENT_BRANCH"
log "Origin URL:  $(git remote get-url origin)"

# Determine the remote tracking ref. If the current branch tracks a
# remote branch, use that. Otherwise default to origin/main.
TRACKING="$(git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || true)"
if [[ -z "$TRACKING" || "$TRACKING" == "@{u}" ]]; then
    REMOTE_REF="origin/${REMOTE_BRANCH:-main}"
    log "No upstream tracking; defaulting to $REMOTE_REF"
else
    REMOTE_REF="$TRACKING"
    log "Tracking:    $REMOTE_REF"
fi

# Make sure the remote ref actually exists locally.
if ! git rev-parse --verify --quiet "$REMOTE_REF" 2>/dev/null; then
    log "Fetching $REMOTE_REF from origin ..."
    git fetch origin "${REMOTE_REF#origin/}" || die "git fetch origin failed"
fi

LOCAL_HEAD="$(git rev-parse HEAD)"
REMOTE_HEAD="$(git rev-parse "$REMOTE_REF")"
log "Local HEAD:  $(git log -1 --oneline $LOCAL_HEAD | head -1)"
log "Remote HEAD: $(git log -1 --oneline $REMOTE_HEAD | head -1)"

if [[ "$LOCAL_HEAD" == "$REMOTE_HEAD" ]]; then
    log "Already up to date."
else
    # 1. Stash uncommitted + untracked so the rebase/merge can run cleanly.
    # `git stash push -u` includes untracked files in the stash.
    STASH_CREATED=0
    if ! git diff --quiet || ! git diff --cached --quiet || [[ -n "$(git ls-files --others --exclude-standard)" ]]; then
        log "Stashing local uncommitted + untracked work ..."
        if git stash push -u -m "$STASH_MSG"; then
            STASH_CREATED=1
        else
            # Nothing to stash is not an error; git stash returns 0 even then
            # on modern git when there are no changes. Fall through.
            STASH_CREATED=0
        fi
    fi

    restore_stash() {
        if [[ "${STASH_CREATED}" == "1" ]]; then
            log "Restoring your uncommitted + untracked work (stash ${STASH_MSG}) ..."
            if git stash pop --quiet; then
                log "Restored."
            else
                log "WARNING: git stash pop reported conflicts."
                log "  Your uncommitted work is safe in 'git stash list' as '${STASH_MSG}'."
                log "  Resolve manually:  cd $REPO_DIR && git stash pop"
            fi
        fi
    }
    trap 'rc=$?; restore_stash; exit $rc' EXIT

    # 2. Fast-forward if local is a clean descendant of remote.
    if git merge-base --is-ancestor "$LOCAL_HEAD" "$REMOTE_HEAD" 2>/dev/null; then
        log "Local is behind remote — fast-forwarding ..."
        git merge --ff-only "$REMOTE_REF" || die "Fast-forward failed (this should not happen for a clean ancestor)"
    # 3. Otherwise, local has commits not on the remote. Rebase them on top.
    elif git merge-base --is-ancestor "$REMOTE_HEAD" "$LOCAL_HEAD" 2>/dev/null; then
        log "Local has unpushed commits — rebasing on top of $REMOTE_REF ..."
        if ! git rebase "$REMOTE_REF"; then
            log "Rebase reported conflicts. Aborting rebase; restoring your work."
            git rebase --abort || true
            # The trap will pop the stash.
            die "Rebase conflicts. Resolve manually:\n  cd $REPO_DIR\n  git rebase $REMOTE_REF   # resolve, then git rebase --continue\n  # or, to discard the rebase: git rebase --abort"
        fi
    else
        # Diverged branches: both have commits the other doesn't.
        # Rebase local onto remote; conflicts → abort.
        log "Local and $REMOTE_REF have diverged — rebasing local on top ..."
        if ! git rebase "$REMOTE_REF"; then
            log "Rebase reported conflicts. Aborting rebase; restoring your work."
            git rebase --abort || true
            die "Diverged branches with conflicts. Resolve manually:\n  cd $REPO_DIR\n  git rebase $REMOTE_REF\n  # or merge: git merge $REMOTE_REF"
        fi
    fi
fi

log "Update complete. New HEAD: $(git log -1 --oneline | head -1)"

# 4. Restart Quickshell so the new code takes effect.
if pgrep -x qs >/dev/null 2>&1; then
    log "Restarting Quickshell ..."
    pkill -x qs || true
    sleep 0.5
    setsid qs -c end4-pC >/tmp/qs.log 2>&1 < /dev/null &
    disown || true
    log "Quickshell restarted."
else
    log "Quickshell was not running; leaving it stopped."
fi
