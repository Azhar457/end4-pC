# 💠 end4-pC System & Configuration Guide (Single Source of Truth)

Dokumentasi ini adalah panduan referensi utama untuk arsitektur, berkas konfigurasi, perintah theming, dan pengaturan desktop environment **end4-pC** (Quickshell Material 3 pada Fedora Linux dengan Hyprland & Niri).

---

## 📁 1. Lokasi Berkas Konfigurasi Utama

| Komponen | Jalur Berkas / Direktori | Keterangan |
|---|---|---|
| **Shell Configuration** | `~/.config/illogical-impulse/config.json` | Konfigurasi utama: Bar, Background, Widgets, Theming, Services |
| **Material 3 Palette** | `~/.local/state/quickshell/user/generated/colors.json` | Warna tema aktif yang di-generate oleh Matugen |
| **Hyprland Config** | `~/.config/hypr/hyprland.conf` | Konfigurasi utama Hyprland |
| **Hyprland Keybinds** | `~/.config/hypr/hyprland/keybinds.conf` | Shortcut keyboard dan mouse Hyprland |
| **Hyprland Rules & Monitors** | `~/.config/hypr/hyprland/rules.conf`, `monitors.conf` | Window rules, monitor scales, animations |
| **Niri Config** | `~/.config/niri/config.kdl` | Konfigurasi compositor Niri (scrollable tiling) |
| **Quickshell Source** | `~/.config/quickshell/end4-pC/` | Source code widget, panel, dan script aktif |

---

## 🎨 2. Wallpaper & Theming Commands

Theming di end4-pC digerakkan oleh **Matugen** (Material You color generator) yang terintegrasi langsung dengan Python environment `~/.local/state/quickshell/.venv`.

### Ganti Wallpaper & Auto-Generate Tema Warna:
```bash
# 1. Ganti wallpaper gambar (otomatis generate palette & apply ke GTK, QT, shell, terminal)
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh /jalur/ke/gambar.png

# 2. Buka GUI file picker untuk memilih wallpaper
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh

# 3. Video wallpaper (mp4, webm, mkv)
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh /jalur/ke/video.mp4
```

### Ubah Mode & Palette Style:
```bash
# Dark Mode
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh --mode dark

# Light Mode
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh --mode light

# Tipe Palette Scheme (opsi: auto, scheme-tonal-spot, scheme-expressive, scheme-monochrome, scheme-fidelity, scheme-neutral, scheme-rainbow)
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh --type scheme-tonal-spot

# Set Warna Aksen Kustom (Hex)
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh --color "#6750A4"

# Re-apply / regenerate tema tanpa mengganti wallpaper
~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh --noswitch
```

---

## ⚙️ 3. Pengaturan Shell (GUI & JSON Schema)

### Melalui GUI Settings:
- Tekan **`Super + I`** untuk membuka panel Settings lengkap (Personalization, Bar, Background Widgets, Services, Hyprland/Niri config).

### Skema Kunci di `~/.config/illogical-impulse/config.json`:
- **`appearance`**:
  - `palette.type`: Jenis palet (`"auto"`, `"scheme-tonal-spot"`, `"scheme-expressive"`, dll.)
  - `palette.accentColor`: Hex custom accent color (string kosong jika mengikuti wallpaper)
  - `transparency.enable`: Aktifkan transparansi Material 3
- **`background`**:
  - `wallpaperPath`: Path wallpaper saat ini
  - `widgets.aiAgent.enable`: Toggle widget Desktop AI Agent
  - `widgets.clock.enable`: Toggle widget Jam desktop
  - `widgets.todo.enable`: Toggle widget To-Do
  - `widgets.media.enable`: Toggle widget Media player
- **`bar`**:
  - Konfigurasi Bar Island, tray, workspacelist, corner styles.

---

## 🛠️ 4. Tools & Perintah Pemeliharaan Shell

```bash
# Deploy perubahan dari repo ke live config
python3 deploy.py

# Rollback ke backup sebelumnya jika config rusak
python3 deploy.py --restore

# Soft-reload / Kill Quickshell daemon
qs -c end4-pC kill
# Menjalankan kembali di background
qs -c end4-pC -d -n
```

---

## 📌 5. Aturan Penting untuk AI Agent:
1. **Wayland-Native Only**: Compositor yang digunakan adalah **Hyprland** dan **Niri**. Jangan pernah menyarankan perintah X11 (`xrandr`, `setxkbmap`), GNOME gsettings shell, atau KDE Plasma panels.
2. **Jangan Mengarang Jalur File**: Selalu gunakan tabel di atas untuk jalur berkas konfigurasi.
3. **Eksekusi Sesuai Permintaan**: Jika user meminta ganti wallpaper, ganti dark/light mode, atau atur widget, jalankan script yang sesuai di atas atau arahkan user ke `Super + I`.
