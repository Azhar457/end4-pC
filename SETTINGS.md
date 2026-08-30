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

### Pengaturan Background Widgets & Hot-Reload:
- File: `~/.config/illogical-impulse/config.json` -> key `"background"."widgets"`.
- Setiap widget memiliki property `"enable": true / false`.
- **⚡ Hot-Reload**: Mengubah nilai `"enable"` pada `config.json` akan **langsung ter-reload otomatis oleh Quickshell tanpa perlu restart shell**.

Daftar nama widget yang tersedia:
- `aiAgent`: Desktop AI Agent
- `calendar`: Kalender
- `clock`: Jam (cookie/digital/pixel)
- `todo`: To-Do List
- `notes`: Catatan Desktop
- `resources`: Monitor Resource (CPU, RAM, Disk)
- `userCard`: Kartu Profil Pengguna
- `worldClock`: Jam Dunia
- `media`: Media Player Controller
- `weather`: Cuaca (memerlukan geocode/network)
- `customImage`: Gambar Kustom Desktop

### Skema Kunci di `~/.config/illogical-impulse/config.json`:
- **`appearance`**:
  - `palette.type`: Jenis palet (`"auto"`, `"scheme-tonal-spot"`, `"scheme-expressive"`, `"scheme-monochrome"`, `"scheme-fidelity"`, `"scheme-neutral"`, `"scheme-rainbow"`)
  - `palette.accentColor`: Hex custom accent color (string kosong `""` jika mengikuti wallpaper, atau format `"#RRGGBB"`)
  - `transparency.enable`: Aktifkan transparansi Material 3 (`true`/`false`)
- **`background`**:
  - `wallpaperPath`: Path wallpaper aktif saat ini
  - `widgets.<widgetName>.enable`: Mengaktifkan / menonaktifkan widget (Hot-reload otomatis!)
- **`bar`** (Taskbar / Top Bar):
  - `autoHide.enable`: Sembunyikan bar otomatis (`true` / `false`)
  - `autoHide.pushWindows`: Mendorong window saat bar muncul (`true` / `false`)
  - `bottom`: Posisi bar (`true`: Bawah / Taskbar, `false`: Atas / Topbar)
  - `cornerStyle`: Gaya sudut bar (`0`: Default, `1`: Small, `2`: Medium, `3`: Full Round)
  - `showBackground`: Background bar (`true` / `false`)

---

## 💻 5. Contoh Tindakan Konkret yang Sering Diminta:

1. **Ubah Taskbar jadi Auto-Hide**:
   Edit `~/.config/illogical-impulse/config.json` -> set `"bar"."autoHide"."enable": true`.
2. **Ganti Warna Aksen**:
   Jalankan: `~/.config/quickshell/end4-pC/scripts/colors/switchwall.sh --color "#FF5722"`
   Atau edit `~/.config/illogical-impulse/config.json` -> `"appearance"."palette"."accentColor": "#FF5722"`.
3. **Disable / Enable Semua Background Widget**:
   Edit `~/.config/illogical-impulse/config.json` -> loop `"background"."widgets"` -> set `"enable": false` (kecuali `"aiAgent"` jika ingin chat tetap ada). Hot-reload otomatis aktif seketika!

---

## 🛠️ 6. Tools & Perintah Pemeliharaan Shell

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
