#!/usr/bin/env bash
set -e

echo "🌌 [SDDM Installer] Memulai instalasi SDDM & Tema Astronaut untuk Fedora 44..."

if [ "$EUID" -ne 0 ]; then
  echo "❌ Tolong jalankan script ini dengan sudo:"
  echo "   sudo bash $0"
  exit 1
fi

echo "📦 1. Menginstall SDDM & dependensi Qt6..."
dnf install -y sddm sddm-wayland-plasma qt6-qtsvg qt6-qtdeclarative qt6-qtmultimedia

echo "🎨 2. Mengkonfigurasi Tema Astronaut..."
mkdir -p /usr/share/sddm/themes/sddm-astronaut-theme
if [ -d "/tmp/sddm-astronaut-theme" ]; then
    cp -r /tmp/sddm-astronaut-theme/* /usr/share/sddm/themes/sddm-astronaut-theme/
else
    git clone --depth=1 https://github.com/Keyitdev/sddm-astronaut-theme.git /usr/share/sddm/themes/sddm-astronaut-theme/
fi

# Link fonts
if [ -d "/usr/share/sddm/themes/sddm-astronaut-theme/Fonts" ]; then
    cp -r /usr/share/sddm/themes/sddm-astronaut-theme/Fonts/* /usr/share/fonts/ 2>/dev/null || true
    fc-cache -f 2>/dev/null || true
fi

echo "⚙️ 3. Mengatur Konfigurasi SDDM..."
mkdir -p /etc/sddm.conf.d
cat << 'THEME_CONF' > /etc/sddm.conf.d/theme.conf
[Theme]
Current=sddm-astronaut-theme

[General]
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
THEME_CONF

echo "🔄 4. Mengalihkan Display Manager dari GDM ke SDDM..."
systemctl disable gdm.service 2>/dev/null || true
systemctl enable sddm.service

echo ""
echo "✅ SDDM & Tema Astronaut berhasil terpasang dan diaktifkan!"
echo "🚀 Anda sekarang siap me-restart PC untuk menikmati Login Screen Astronaut yang immersive!"
