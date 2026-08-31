# Stabilizer — the recursive-stability answer for end4-pC

The end4-pC shell is a Quickshell (Qt/QML) compositor running a fork of
end-4's dots-hyprland. On this laptop, the user runs an AI coding
agent (the `opencode` CLI) in the same session. The agent has a
filesystem MCP that lets it read and write any file under
`/home/jars/` — including `~/.config/quickshell/end4-pC/`. When the
agent edits a tracked fork file, the user's last in-shell tweak
disappears on the next save. That was the root cause of the
recurring "the widget closes on its own" / "the wallpaper doesn't
change" / "mp4 doesn't play" symptoms: the agent kept reverting
the fixes between the user's actions.

The safe `update-fork.sh` updater (see
`scripts/system/update-fork.sh`) prevents upstream-driven data loss
(the old `git clone + mv + rm -rf` flow in `About.qml` `runUpdateDots`
that wiped every "Update Dots" click). But it does nothing to
prevent in-session reverts by a tool that can write to the fork
directly. This stabilizer solves that.

## What it does

Every 30 seconds (via a systemd user timer), the stabilizer runs
`scripts/system/stabilize-fork.sh`, which:

1. `cd` to the fork repo (default `~/.config/quickshell/end4-pC`).
2. For every tracked file that differs from `HEAD`, run
   `git checkout HEAD -- <file>`. This replaces the working-tree
   content of that file with the committed version, undoing the
   reverts without touching anything else.
3. Untracked files are NEVER touched. That includes:
   - the `agent/`, `rice-doctor`, `SafeWidgetLoader.qml`
   - the `.backups/` snapshots from prior destructive updates
   - any custom wallpapers, JSON config, or AI agent sessions
4. A 2-second "mid-write" safety margin skips files modified
   within the last 2 seconds, so an in-flight edit is not
   truncated. With a 30-second cadence this leaves a tiny race
   window that the 30-second timeout bounds.
5. Silent on no-op runs; prints a one-line summary only when
   something was restored.

## Why 30 seconds

Frequent enough that an agent's revert is undone before the user
notices (the user's next interaction is typically > 30 s after the
agent's edit). Not so frequent that the script's overhead matters
(it is one `git diff --name-only HEAD` plus zero or more
`git checkout HEAD -- <file>`).

## Install

```
bash scripts/system/install-stabilizer.sh
```

This symlinks `stabilize-fork.service` and `stabilize-fork.timer`
into `~/.config/systemd/user/`, runs `daemon-reload`, and enables +
starts the timer. Verify:

```
systemctl --user list-timers | grep stabilize-fork
systemctl --user status stabilize-fork.service
```

## Uninstall

```
bash scripts/system/uninstall-stabilizer.sh
```

## Manual / fallback use

```
# one-shot, restores every file that differs from HEAD
REPO_DIR=/path/to/fork bash scripts/system/stabilize-fork.sh

# foreground loop, every N seconds
STABILIZE_INTERVAL=30 REPO_DIR=/path/to/fork \
  nohup bash scripts/system/stabilize-fork-watch.sh >/dev/null 2>&1 &
```

`stabilize-fork-watch.sh` is the fallback for hosts without a
working `systemctl --user` (e.g. some container / chroot setups).

## Letting the agent keep a local edit

The stabilizer overwrites any tracked file that drifts from `HEAD`.
If you want the agent (or yourself) to keep a local tweak, **commit
it** — once it's in HEAD, the stabilizer stops overwriting it. That
is intentional: tracked files reflect the "agreed" state of the
fork; untracked files reflect your local data. Use the existing
work tree as a `git add` / `git commit` scratch space; use a separate
directory (or the `.backups/` snapshots listed by
`scripts/system/list-update-backups.sh`) for data you don't want in
the repo.

## What it does NOT do

- It does not touch the upstream `origin/main` or run any network
  command. It only re-applies the local `HEAD`.
- It does not push, fetch, or change branches.
- It does not edit the safe updater or any other tool — those are
  committed and the stabilizer treats them as part of "the
  intended state".
- It does not touch the opencode process or its MCP. The agent
  keeps running; its edits are simply undone within 30 seconds.

## Operational verification

To confirm the stabilizer is doing its job, in one terminal run:

```
journalctl --user -u stabilize-fork.service -f
```

In another, edit a tracked file (simulating the agent):

```
echo "// agent revert" >> ~/.config/quickshell/end4-pC/modules/ii/background/Background.qml
```

Within 30 seconds, the journal will show
`stabilize-fork.sh[...]: restored 1 file(s) from HEAD: ...` and the
extra line will be gone.

## Files in this directory

- `stabilize-fork.sh` — the core script
- `stabilize-fork.service`, `stabilize-fork.timer` — systemd user
  units
- `stabilize-fork-watch.sh` — foreground loop fallback
- `install-stabilizer.sh`, `uninstall-stabilizer.sh` — installers
- `list-update-backups.sh` — inventory of the pre-fix
  `~/.config/quickshell/.backups/end4-pC_<ts>/` snapshots left by
  the old destructive updater, with a short recovery recipe.
- `update-fork.sh` — the safe in-place updater (previous commit)
  that prevents upstream-driven data loss.
