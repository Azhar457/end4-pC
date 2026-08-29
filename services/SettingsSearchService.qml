pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs.modules.common

Singleton {
    id: root

    property string query: ""
    property var searchMatches: []
    property int currentMatchIdx: 0

    readonly property var allSettingsItems: [
        // Quick (page 0)
        { title: "Dark Theme / Light Theme", page: 0, pageName: "quick", term: "theme", keywords: "dark light color theme mode" },
        { title: "Wallpaper Mode & Image", page: 0, pageName: "quick", term: "wallpaper", keywords: "wallpaper background image picture" },
        { title: "Transparency", page: 0, pageName: "quick", term: "transparency", keywords: "transparency opacity alpha blur" },
        { title: "Screen Rounding Corner", page: 0, pageName: "quick", term: "rounding", keywords: "corner rounding radius border" },

        // General (page 1)
        { title: "User Profile & Avatar", page: 1, pageName: "general", term: "profile", keywords: "user avatar name account" },
        { title: "Display Name", page: 1, pageName: "general", term: "name", keywords: "username name profile display" },
        { title: "Time Format & Clock Preview", page: 1, pageName: "general", term: "time", keywords: "time clock format seconds date hour minute" },
        { title: "Weather City & Location", page: 1, pageName: "general", term: "weather", keywords: "weather city location forecast" },
        { title: "Font & Typography", page: 1, pageName: "general", term: "font", keywords: "font text typography style size" },

        // Bar (page 2)
        { title: "Autohide Bar (Intelhide / Automatic)", page: 2, pageName: "bar", term: "autohide", keywords: "autohide automatic intelhide hide bar hover reveal" },
        { title: "Bar Position (Top / Bottom / Left / Right)", page: 2, pageName: "bar", term: "position", keywords: "bar position top bottom left right placement" },
        { title: "Bar Height & Padding", page: 2, pageName: "bar", term: "height", keywords: "bar size height width padding thickness" },
        { title: "Bar Widgets & Layout", page: 2, pageName: "bar", term: "widgets", keywords: "bar widgets components items reorder" },
        { title: "Show Bar Background", page: 2, pageName: "bar", term: "background", keywords: "bar background show color container" },
        { title: "Show Bar Frame", page: 2, pageName: "bar", term: "frame", keywords: "bar frame border outline" },
        { title: "Workspaces Widget", page: 2, pageName: "bar", term: "workspaces", keywords: "workspaces virtual desktop pager" },
        { title: "Media & Music Player Widget", page: 2, pageName: "bar", term: "media", keywords: "music media player song audio track" },
        { title: "Clock & Date Widget", page: 2, pageName: "bar", term: "clock", keywords: "clock time date schedule calendar" },
        { title: "Battery Indicator", page: 2, pageName: "bar", term: "battery", keywords: "battery power charge level" },
        { title: "Bluetooth Indicator", page: 2, pageName: "bar", term: "bluetooth", keywords: "bluetooth wireless connect device" },
        { title: "Network Speed Widget", page: 2, pageName: "bar", term: "network", keywords: "network speed internet wifi throughput" },
        { title: "System Tray (SysTray)", page: 2, pageName: "bar", term: "tray", keywords: "tray systray icons status applet" },

        // Desktop (page 3)
        { title: "Wallpaper & Background", page: 3, pageName: "desktop", term: "wallpaper", keywords: "wallpaper image background picture showcase" },
        { title: "Desktop Widgets (Clock / Media / System)", page: 3, pageName: "desktop", term: "widgets", keywords: "desktop widgets clock media system stats" },
        { title: "Background Blur", page: 3, pageName: "desktop", term: "blur", keywords: "blur background desktop frosted glass" },
        { title: "Centered Wallpaper Fit", page: 3, pageName: "desktop", term: "centered", keywords: "centered wallpaper fit stretch contain" },

        // Interface (page 4)
        { title: "UI Corner Rounding", page: 4, pageName: "interface", term: "rounding", keywords: "corner rounding border radius curve" },
        { title: "Border Width & Color", page: 4, pageName: "interface", term: "border", keywords: "border width color outline stroke" },
        { title: "Color Palette & Accent", page: 4, pageName: "interface", term: "color", keywords: "color theme palette accent material you" },
        { title: "On Screen Display (OSD)", page: 4, pageName: "interface", term: "osd", keywords: "osd volume brightness overlay popup" },
        { title: "Notifications Style", page: 4, pageName: "interface", term: "notification", keywords: "notification alert popup toast banner" },

        // Services (page 5)
        { title: "AI Assistant (9Router / Models / API Key)", page: 5, pageName: "services", term: "ai", keywords: "ai model 9router claude gemini api key prompt system llm" },
        { title: "Web Search & Base URL", page: 5, pageName: "services", term: "web search", keywords: "web search url base engine google brave prefix browse internet" },
        { title: "Search Prefixes & Shortcuts", page: 5, pageName: "services", term: "prefixes", keywords: "prefixes search shortcuts action clipboard emojis icons shell web apps keybinds" },
        { title: "Networking & User Agent", page: 5, pageName: "services", term: "networking", keywords: "networking user agent connection http header" },
        { title: "Music Recognition (Shazam)", page: 5, pageName: "services", term: "music recognition", keywords: "music recognition shazam sound audio recognize timeout" },
        { title: "Save Paths (Video Recording & Screenshots)", page: 5, pageName: "services", term: "save paths", keywords: "save paths screenshot video recording path directory folder" },
        { title: "System Updates (Check Interval)", page: 5, pageName: "services", term: "system updates", keywords: "system updates check interval dnf pacman upgrade" },
        { title: "Weather Service & Units", page: 5, pageName: "services", term: "weather", keywords: "weather city location gps fahrenheit celsius polling" },
        { title: "Translator (Languages & Google Cloud)", page: 5, pageName: "services", term: "translator", keywords: "translator language translate google cloud ai" },
        { title: "Cliphist Clipboard Manager", page: 5, pageName: "services", term: "cliphist", keywords: "cliphist clipboard history copy paste buffer" },
        { title: "Brightness Controller", page: 5, pageName: "services", term: "brightness", keywords: "brightness screen light display backlight" },

        // Hyprland (page 6)
        { title: "Gaps Out & Gaps In", page: 6, pageName: "hyprland", term: "gaps", keywords: "gaps hyprland spacing margin padding window" },
        { title: "Active Window Opacity", page: 6, pageName: "hyprland", term: "opacity", keywords: "opacity active window transparency alpha" },
        { title: "Inactive Window Opacity", page: 6, pageName: "hyprland", term: "opacity", keywords: "opacity inactive window transparency unfocused" },
        { title: "Autostart Apps (Automatic Startup)", page: 6, pageName: "hyprland", term: "autostart", keywords: "autostart automatic startup boot apps background" },
        { title: "Window Animations & Elastic Presets", page: 6, pageName: "hyprland", term: "animations", keywords: "animations elastic motion speed bezier curves" },
        { title: "Blur Size & Passes", page: 6, pageName: "hyprland", term: "blur", keywords: "blur hyprland glass kawase passes" },
        { title: "Window Shadow", page: 6, pageName: "hyprland", term: "shadow", keywords: "shadow window elevation depth drop" },

        // About (page 7)
        { title: "System Info & Distro Specs", page: 7, pageName: "about", term: "system", keywords: "system info specs cpu ram gpu host os distro" },
        { title: "Kernel & Hardware Details", page: 7, pageName: "about", term: "kernel", keywords: "kernel hardware linux version uptime" },
        { title: "Check for Dotfiles Updates", page: 7, pageName: "about", term: "update", keywords: "update dotfiles git version commit" }
    ]

    function search(queryString) {
        root.query = queryString.trim().toLowerCase();
        if (root.query.length === 0) {
            root.searchMatches = [];
            root.currentMatchIdx = 0;
            return [];
        }

        let matches = [];
        for (let i = 0; i < root.allSettingsItems.length; i++) {
            let item = root.allSettingsItems[i];
            if (item.title.toLowerCase().includes(root.query) ||
                item.keywords.toLowerCase().includes(root.query) ||
                item.term.toLowerCase().includes(root.query)) {
                matches.push(item);
            }
        }
        root.searchMatches = matches;
        root.currentMatchIdx = 0;
        return matches;
    }

    function jumpTo(idx, settingsRoot, pagesRepeater) {
        if (root.searchMatches.length === 0) return;
        if (idx < 0 || idx >= root.searchMatches.length) return;
        root.currentMatchIdx = idx;
        const match = root.searchMatches[idx];

        let targetPageIdx = match.page;
        if (match.pageName && settingsRoot && settingsRoot.pages) {
            let pIdx = settingsRoot.pages.findIndex(p => p.name.toLowerCase().includes(match.pageName.toLowerCase()));
            if (pIdx >= 0) targetPageIdx = pIdx;
        }

        if (settingsRoot) {
            settingsRoot.currentPage = targetPageIdx;
            settingsRoot.showingProfile = false;
        }

        if (pagesRepeater) {
            let loader = pagesRepeater.itemAt(targetPageIdx);
            if (loader && loader.item && typeof loader.item.goTo === "function") {
                loader.item.goTo(match.term);
            } else if (loader) {
                let conn = function() {
                    if (loader.item && typeof loader.item.goTo === "function") {
                        loader.item.goTo(match.term);
                    }
                    loader.onLoaded.disconnect(conn);
                };
                loader.onLoaded.connect(conn);
            }
        }
    }

    function next(settingsRoot, pagesRepeater) {
        if (root.searchMatches.length === 0) return;
        jumpTo((root.currentMatchIdx + 1) % root.searchMatches.length, settingsRoot, pagesRepeater);
    }

    function prev(settingsRoot, pagesRepeater) {
        if (root.searchMatches.length === 0) return;
        jumpTo((root.currentMatchIdx - 1 + root.searchMatches.length) % root.searchMatches.length, settingsRoot, pagesRepeater);
    }
}
