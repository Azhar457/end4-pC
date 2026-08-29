<div align="center">

# 💠 end4-pC (Fedora 44 Hyprland Edition)

**A tailored, rock-solid fork of [end4-pC](https://github.com/pctrade/end4-pC) & [illogical-impulse](https://github.com/end-4/dots-hyprland) optimized natively for Fedora 44 Linux.**  
Maintained and enhanced by **[@Azhar457](https://github.com/Azhar457)**

[![Fedora 44](https://img.shields.io/badge/Fedora-44%20Rawhide%2FWorkstation-51A2DA?logo=fedora&logoColor=white)](#)
[![Hyprland](https://img.shields.io/badge/Hyprland-Wayland%20Compositor-00ADD8?logo=wayland&logoColor=white)](#)
[![Quickshell](https://img.shields.io/badge/Quickshell-Material%203%20Qt6-41CD52?logo=qt&logoColor=white)](#)
[![9Router Plinian](https://img.shields.io/badge/AI%20Gateway-9Router%20Plinian-FF6F00)](#)

</div>

---

## 🌟 Highlights & Fedora 44 Enhancements

Unlike upstream configurations designed exclusively for Arch Linux / AUR, this fork solves all Fedora compatibility hurdles while enhancing UX and system modularity:

* 🐧 **Native Fedora Package Management**: Integrated universal updater that queries `dnf` natively instead of failing on Arch's `checkupdates`.
* 🎨 **Material You & Matugen Integration**: Standalone `matugen` 4.2.0 integration and Python `materialyoucolor` runtime isolation for 100% reliable Light/Dark theme switching.
* 🎯 **Native Wayland Color Eyedropper**: Built-in `grim` + `slurp` + `PIL` color-picker bridge for real-time wallpaper accent selection.
* 🔍 **Dedicated Search Engine Singleton (`SettingsSearchService.qml`)**: Clean architectural separation of settings indexing from UI rendering, supporting deep-link jump, result counters, and glowing pulse highlights.
* 📐 **Fluid & Responsive Layout**: Fluid anchor layouts preventing right-side clipping on small or wide screens.
* 🤖 **AI Gateway Ready**: Seamless native bridge for `9router-plinian` and `Hermes Desktop`.

---

## ⚡ Quick Installation (Fedora 44)

### 1. Prerequisites
Ensure required packages and Python libraries are available:
```bash
# Core tools
sudo dnf install -y hyprland quickshell grim slurp ImageMagick jq python3 python3-pip

# Material You virtualenv setup
python3 -m venv ~/.local/state/quickshell/.venv
~/.local/state/quickshell/.venv/bin/pip install materialyoucolor Pillow
```

### 2. Clone & Run
```bash
git clone https://github.com/Azhar457/end4-pC.git ~/.config/quickshell/end4-pC
killall qs 2>/dev/null; qs -c end4-pC > /dev/null 2>&1 & disown
```

---

## 🛠️ Development & Deployment Workflow

This repository includes a dedicated hot-swapping tool (`deploy.py`) inspired by modern dev-lab toolkits:

```bash
# 1. Deploy current working tree to live ~/.config/quickshell/end4-pC (with automatic timestamped backup)
python3 deploy.py

# 2. Instant Rollback if anything breaks
python3 deploy.py --restore

# 3. Inspect incoming upstream changes safely before merging
python3 deploy.py --diff-upstream

# 4. Check repo & live status
python3 deploy.py --status
```

---

## 🤝 Upstream Provenance & Sync Strategy

This project maintains clean dual-remotes:
* **`origin`**: Your custom fork (`git@github.com:Azhar457/end4-pC.git`)
* **`upstream`**: Official repository (`https://github.com/pctrade/end4-pC.git`)

To sync with upstream updates without losing Fedora patches:
```bash
git fetch upstream
git merge upstream/main
python3 deploy.py
```

---

<div align="center">
  <sub>Engineered with precision for Fedora Linux 44. Based on the incredible work of @end-4 and @pctrade.</sub>
</div>
