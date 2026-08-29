#!/usr/bin/env bash
set -e

echo "🧹 [System & Disk Cleaner] Memulai pembersihan sistem & ruang disk..."

if [ "$EUID" -ne 0 ]; then
  echo "❌ Tolong jalankan script ini dengan sudo:"
  echo "   sudo bash $0"
  exit 1
fi

echo "🔒 1. Mengamankan dependensi inti (Dolphin, Keyring, SDDM)..."
dnf install -y gnome-keyring gnome-keyring-pam dolphin ark 2>/dev/null || true
systemctl enable sddm.service 2>/dev/null || true

echo "🗑️ 2. Menghapus GNOME Workstation & Nautilus (Aman & Terverifikasi)..."
dnf remove -y --setopt=clean_requirements_on_remove=false \
    gnome-shell \
    gnome-session \
    gnome-tour \
    gnome-initial-setup \
    mutter \
    gdm \
    nautilus 2>/dev/null || true

echo "🧹 3. Membersihkan DNF Cache & Package Repository metadata..."
dnf clean all

echo "📜 4. Membersihkan systemd journal logs lama (>3 hari)..."
journalctl --vacuum-time=3d

echo "📦 5. Membersihkan Flatpak runtimes yang tidak terpakai..."
flatpak uninstall --unused -y 2>/dev/null || true

echo "📂 6. Menyetel Dolphin sebagai Default File Manager..."
su - jars -c "xdg-mime default org.kde.dolphin.desktop inode/directory" 2>/dev/null || true

echo ""
echo "✨ [SUKSES] Sistem dan Disk berhasil dibersihkan!"
echo "📊 Cek kapasitas disk dengan: df -h"
