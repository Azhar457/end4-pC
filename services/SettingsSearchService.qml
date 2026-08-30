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
        // Generic umbrella entry for 'utili' / 'util' / 'utilb' / 'utilbutton'
        { title: "Utility Buttons (Bar)", page: 2, pageName: "bar", term: "utility", keywords: "utilities util utili utilb utilbutton systray tray helper shortcut quick color picker screen snip screenshot record video dark light mode mic microphone wallpaper image" },
        { title: "Show Color Picker (Util Button)", page: 2, pageName: "bar", term: "showColorPicker", keywords: "colorpicker showcolorpicker color picker util utilb colorize hyprpicker hex" },
        { title: "Show Screen Snip (Util Button)", page: 2, pageName: "bar", term: "showScreenSnip", keywords: "showscreensnip snip screenshot region util utilb grim slurp rectangle capture" },
        { title: "Show Microphone Toggle (Util Button)", page: 2, pageName: "bar", term: "showMicToggle", keywords: "showmictoggle mic microphone mute unmute util utilb pipewire" },
        { title: "Show Keyboard Toggle (Util Button)", page: 2, pageName: "bar", term: "showKeyboardToggle", keywords: "showkeyboardtoggle onboard osk virtual keyboard util utilb" },
        { title: "Show Wallpaper Toggle (Util Button)", page: 2, pageName: "bar", term: "showWallpaperToggle", keywords: "showwallpapertoggle wallpaper util utilb picker background" },
        { title: "Show Dark Mode Toggle (Util Button)", page: 2, pageName: "bar", term: "showDarkModeToggle", keywords: "showdarkmodetoggle dark light mode toggle theme util utilb appearance m3" },
        { title: "Show Performance Profile Toggle (Util Button)", page: 2, pageName: "bar", term: "showPerformanceProfileToggle", keywords: "showperformanceprofiletoggle performance profile power util utilb" },
        { title: "Show Screen Record (Util Button)", page: 2, pageName: "bar", term: "showScreenRecord", keywords: "showscreenrecord record video util utilb wf-recorder wf rec" },
        { title: "Show Image Picker (Util Button)", page: 2, pageName: "bar", term: "imagepicker", keywords: "image picker util utilb imagepicker screenshot upload copy select" },
        { title: "Snip Region / Screenshot", page: 2, pageName: "bar", term: "screenshot", keywords: "snip screenshot region util utilb grim slurp capture" },
        { title: "Wallpaper Picker (Bar Button)", page: 2, pageName: "bar", term: "wallpaperpicker", keywords: "wallpaper util utilb picker background image" },

        // Desktop (page 3)
        { title: "Wallpaper & Background", page: 3, pageName: "desktop", term: "wallpaper", keywords: "wallpaper image background picture showcase live video gif animated mp4 webm" },
        { title: "Live Wallpaper (Video / GIF)", page: 3, pageName: "desktop", term: "livewallpaper", keywords: "live wallpaper video gif animated mp4 webm play pause auto pause battery fullscreen lock" },
        { title: "Desktop Widgets (Clock / Media / System)", page: 3, pageName: "desktop", term: "widgets", keywords: "desktop widgets clock media system stats" },
        { title: "AI Agent Desktop Widget", page: 3, pageName: "desktop", term: "aiAgent", keywords: "ai agent chat gpt gemini opencode tool calling widget desktop hyprland" },
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

    // Re-run search whenever the query changes so external widgets can
    // bind against `searchMatches` and see live results.
    function search(queryString) {
        root.query = (queryString || "").trim().toLowerCase();
        if (root.query.length === 0) {
            root.searchMatches = [];
            root.currentMatchIdx = 0;
            return [];
        }

        let matches = [];
        for (let i = 0; i < root.allSettingsItems.length; i++) {
            const item = root.allSettingsItems[i];
            const haystack = (item.title + " " + item.keywords + " " + item.term).toLowerCase();
            // Substring match is enough for short queries; split into tokens
            // so "wallpaper theme" still finds "Wallpaper & Background".
            const tokens = root.query.split(/\s+/).filter(t => t.length > 0);
            const allMatch = tokens.every(t => haystack.includes(t));
            if (allMatch) {
                // Avoid ES2018 object spread — use Object.assign + tracked score.
                matches.push(Object.assign({}, item, { _score: tokens.length * 100 + haystack.indexOf(root.query) }));
            }
        }
        // Best match first: longer queries (more tokens) + earlier substring
        matches.sort((a, b) => a._score - b._score);
        // Strip the helper key
        matches = matches.map(m => {
            const copy = Object.assign({}, m);
            delete copy._score;
            return copy;
        });
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
            const trigger = () => {
                if (loader && loader.item && typeof loader.item.goTo === "function") {
                    loader.item.goTo(match.term);
                }
                // After the page has had a moment to scroll, ping the highlight
                // so the target box can pulse for a moment.
                root.highlightRequested(match.term, targetPageIdx);
            };
            if (loader && loader.item && typeof loader.item.goTo === "function") {
                trigger();
            } else if (loader) {
                let conn = function() {
                    if (loader.item) trigger();
                    loader.onLoaded.disconnect(conn);
                };
                loader.onLoaded.connect(conn);
            }
        }
    }

    // Emitted whenever the search should visually highlight a target box on
    // the destination page. Subscribers (ContentPage, ConfigRow) animate a
    // pulsing rectangle around the term they just opened.
    signal highlightRequested(string term, int pageIndex)

    function next(settingsRoot, pagesRepeater) {
        if (root.searchMatches.length === 0) return;
        jumpTo((root.currentMatchIdx + 1) % root.searchMatches.length, settingsRoot, pagesRepeater);
    }

    function prev(settingsRoot, pagesRepeater) {
        if (root.searchMatches.length === 0) return;
        jumpTo((root.currentMatchIdx - 1 + root.searchMatches.length) % root.searchMatches.length, settingsRoot, pagesRepeater);
    }
}
