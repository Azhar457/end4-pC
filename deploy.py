#!/usr/bin/env python3
"""
end4-pC Deploy Tool (Fedora 44 / Quickshell Edition)
Safely hot-swaps working tree into ~/.config/quickshell/end4-pC with atomic backups & instant rollback.
"""

import sys
import os
import shutil
import subprocess
import glob
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent
LIVE_TARGET = Path.home() / ".config" / "quickshell" / "end4-pC"
BACKUP_DIR = Path.home() / ".config" / "quickshell" / ".backups"

def run_cmd(cmd, check=True):
    res = subprocess.run(cmd, shell=True, text=True, capture_output=True)
    if check and res.returncode != 0:
        print(f"[ERROR] Command failed: {cmd}\n{res.stderr.strip()}", file=sys.stderr)
    return res

def ensure_dirs():
    BACKUP_DIR.mkdir(parents=True, exist_ok=True)
    LIVE_TARGET.parent.mkdir(parents=True, exist_ok=True)

def backup_live():
    ensure_dirs()
    if not LIVE_TARGET.exists():
        return None
    stamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    backup_path = BACKUP_DIR / f"end4-pC_{stamp}"
    print(f"📦 Creating backup at: {backup_path}")
    shutil.copytree(LIVE_TARGET, backup_path, ignore=shutil.ignore_patterns(".git", "*.bak*"))
    
    # Prune old backups (keep last 5)
    backups = sorted(glob.glob(str(BACKUP_DIR / "end4-pC_*")), reverse=True)
    for old in backups[5:]:
        shutil.rmtree(old, ignore_errors=True)
    return backup_path

def deploy():
    print("🚀 Deploying end4-pC to live runtime...")
    backup_live()
    
    # Use rsync to mirror working tree excluding .git, .vscode, deploy.py
    cmd = (
        f"rsync -av --delete "
        f"--exclude='.git' "
        f"--exclude='.vscode' "
        f"--exclude='deploy.py' "
        f"'{REPO_ROOT}/' '{LIVE_TARGET}/'"
    )
    res = run_cmd(cmd)
    if res.returncode == 0:
        print("✅ Successfully deployed to ~/.config/quickshell/end4-pC")
        # Soft reload if quickshell is running
        run_cmd("qs -c end4-pC ipc call settings toggle 2>/dev/null || true", check=False)
        print("🔄 Quickshell IPC triggered.")
    else:
        print("❌ Deploy failed!", file=sys.stderr)

def restore():
    ensure_dirs()
    backups = sorted(glob.glob(str(BACKUP_DIR / "end4-pC_*")), reverse=True)
    if not backups:
        print("⚠️ No backups found to restore.")
        return
    latest = backups[0]
    print(f"⏪ Restoring latest backup: {latest}")
    if LIVE_TARGET.exists():
        shutil.rmtree(LIVE_TARGET)
    shutil.copytree(latest, LIVE_TARGET)
    print("✅ Rollback complete! Reloading Quickshell...")
    run_cmd("qs -c end4-pC ipc call settings toggle 2>/dev/null || true", check=False)

def diff_upstream():
    print("🌐 Fetching upstream changes...")
    run_cmd(f"git -C '{REPO_ROOT}' fetch upstream", check=False)
    res = run_cmd(f"git -C '{REPO_ROOT}' log HEAD..upstream/main --oneline 2>/dev/null || git -C '{REPO_ROOT}' log HEAD..upstream/master --oneline", check=False)
    if res.stdout.strip():
        print("🔍 Incoming upstream commits:")
        print(res.stdout)
    else:
        print("✨ Up to date with upstream!")

def status():
    print(f"📍 Repo: {REPO_ROOT}")
    print(f"🎯 Target: {LIVE_TARGET}")
    res = run_cmd(f"git -C '{REPO_ROOT}' status -s", check=False)
    print(f"📝 Local changes in repo:\n{res.stdout or 'Clean'}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        arg = sys.argv[1]
        if arg == "--restore":
            restore()
        elif arg == "--diff-upstream":
            diff_upstream()
        elif arg == "--status":
            status()
        elif arg in ("-h", "--help"):
            print("Usage:")
            print("  python3 deploy.py                 Deploy working tree to live config with auto-backup")
            print("  python3 deploy.py --restore       Rollback to the most recent backup")
            print("  python3 deploy.py --diff-upstream Fetch & show changes from upstream repo")
            print("  python3 deploy.py --status        Show git status and paths")
        else:
            print(f"Unknown argument: {arg}")
    else:
        deploy()
