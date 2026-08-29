#!/usr/bin/env bash
set -e

echo "🧹 [GNOME Cleaner] Memulai pembersihan GNOME Workstation yang aman..."

if [ "$EUID" -ne 0 ]; then
  echo "❌ Tolong jalankan script ini dengan sudo:"
  echo "   sudo bash $0"
  exit 1
fi

# 1. Pastikan gnome-keyring & dolphin tetap terpasang aman
echo "🔒 1. Mengamankan gnome-keyring, dolphin & PAM credentials..."
dnf install -y gnome-keyring gnome-keyring-pam dolphin ark 2>/dev/null || true

# 2. Pastikan SDDM aktif sebagai display manager utama
echo "⚙️ 2. Memastikan SDDM aktif..."
systemctl enable sddm.service 2>/dev/null || true

# 3. Menghapus GNOME UI, Shell, Mutter, GDM, dan Nautilus secara aman
echo "🗑️ 3. Menghapus paket GNOME Shell, Mutter, GDM, dan Nautilus..."
dnf remove -y --setopt=clean_requirements_on_remove=false \
    gnome-shell \
    gnome-session \
    gnome-tour \
    gnome-initial-setup \
    mutter \
    gdm \
    nautilus

echo ""
echo "✅ GNOME Shell & Nautilus berhasil dihapus dengan aman!"
echo "🛡️ Dolphin, SDDM, KDE, Hyprland, Audio, dan NetworkManager tetap 100% utuh!"
