# end4-pC Agent Guidelines & UI Consistency Protocol

## Architecture Overview
This repository (`end4-pC`) is a modular Quickshell (Qt6/QML) Material 3 desktop shell for Wayland (Hyprland primary, Niri secondary).
- **Core Widgets**: `modules/common/widgets/`
- **Shell Panels & Bar**: `modules/ii/`
- **Services**: `services/`
- **Configuration Defaults**: `modules/common/Config.qml`
- **Theme & Design Tokens**: `modules/common/Appearance.qml`
- **Runtime Deployment**: `deploy.py` -> `~/.config/quickshell/end4-pC`
- **System Doctor & Auditing**: `scripts/system/rice-doctor`

---

## 🎨 UI Consistency & Design System Rules (MANDATORY)

### 1. Colors & Palette
- **NEVER** use hardcoded hex colors (`#ffffff`, `#1e1e1e`, `#000000`) or raw `rgb()` strings in QML.
- **ALWAYS** reference `Appearance.colors.*`:
  - Background layers: `Appearance.colors.colLayer0`, `colLayer1`, `colLayer2`
  - Accent / Brand: `Appearance.colors.colPrimary`, `colPrimaryContainer`, `colSecondary`
  - Typography: `Appearance.colors.colText`, `colSubtext`, `colMuted`
  - Outlines: `Appearance.colors.colOutline`, `colOutlineVariant`

### 2. Geometry & Corner Radii
- **NEVER** hardcode arbitrary pixel radius numbers (e.g. `radius: 12`, `radius: 8`).
- **ALWAYS** reference active theme tokens from `Appearance.rounding.*`:
  - Main Windows / Dialogs: `Appearance.rounding.windowRounding`
  - Inner / Sub-components: `Appearance.rounding.unsharpen`
  - Rounded pills / circles: `Appearance.rounding.full`

### 3. Canonical Base Components
- **Text**: ALWAYS use `StyledText {}` instead of raw `Text {}`.
- **Buttons / Clickables**: ALWAYS use `RippleButton {}`, `ButtonMouseArea {}`, or `StyledButton {}`.
- **Icons**: ALWAYS use `MaterialSymbol {}` or `CustomIcon {}` rather than inline custom SVG code.
- **Settings & Dialog Pages**: ALWAYS scaffold pages with `ContentPage {}` + `ContentSection {}` + `ConfigRow {}`.

### 4. Layout Resilience & Anti-Deadlock Rules
- **NEVER** bind `implicitWidth`/`implicitHeight` to `visible` when `visible` itself depends on child dimensions. This creates circular dependency layout collapses.
- **Dynamic Loaders**: When wrapping dynamically loaded widgets, ensure attached properties (`Layout.fillWidth`, `Layout.fillHeight`, `Layout.alignment`) are native and propagated cleanly.
- **Network & Subprocess Guard**: Every `curl` or external command in `services/` MUST specify timeout flags (e.g. `--connect-timeout 10`) and handle non-zero exit codes on `onExited` to reset UI loading spinners.

---

## 🚀 Workflow & Verification
1. Make changes in `/mnt/data_d/Projects/end4-pC`.
2. Deploy changes to runtime: `python3 deploy.py`.
3. Check health and verify: `rice-doctor`.
