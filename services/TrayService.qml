pragma Singleton

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.SystemTray

Singleton {
    id: root

    property bool smartTray: Config.options.tray?.filterPassive ?? false
    property bool invertPins: Config.options.tray?.invertPinnedItems ?? false

    property int updateTrigger: 0

    function requestUpdate() {
        updateTrigger++;
    }

    // Reactively monitor all individual items for asynchronous property updates (ready, id, status, icon)
    Instantiator {
        model: SystemTray.items
        delegate: Item {
            required property var modelData
            readonly property var item: modelData

            Connections {
                target: item
                function onIdChanged() { root.requestUpdate() }
                function onStatusChanged() { root.requestUpdate() }
                function onIconChanged() { root.requestUpdate() }
                function onReady() { root.requestUpdate() }
            }
        }
    }

    Connections {
        target: SystemTray.items
        function onValuesChanged() { root.requestUpdate() }
    }

    // Auto-launch xembedsniproxy to bridge X11/XWayland tray items (Electron, Wine, Steam, etc.) to SNI
    Process {
        id: xembedProxyProc
        running: true
        command: ["bash", "-c", "which xembedsniproxy >/dev/null 2>&1 && ! pgrep -x xembedsniproxy >/dev/null 2>&1 && exec xembedsniproxy"]
    }

    property list<var> itemsInUserList: {
        root.updateTrigger;
        const pinnedList = Config.options.tray?.pinnedItems ?? [];
        return SystemTray.items.values.filter(i => {
            if (!i) return false;
            const itemId = i.id || "";
            const isPinned = pinnedList.includes(itemId);
            if (!isPinned) return false;
            if (root.smartTray && i.status === Status.Passive) return false;
            return true;
        });
    }

    property list<var> itemsNotInUserList: {
        root.updateTrigger;
        const pinnedList = Config.options.tray?.pinnedItems ?? [];
        return SystemTray.items.values.filter(i => {
            if (!i) return false;
            const itemId = i.id || "";
            const isPinned = pinnedList.includes(itemId);
            if (isPinned) return false;
            if (root.smartTray && i.status === Status.Passive) return false;
            return true;
        });
    }

    property list<var> pinnedItems: invertPins ? itemsNotInUserList : itemsInUserList
    property list<var> unpinnedItems: invertPins ? itemsInUserList : itemsNotInUserList

    function getTooltipForItem(item) {
        if (!item) return "";
        var result = (item.tooltipTitle && item.tooltipTitle.length > 0) ? item.tooltipTitle
                : ((item.title && item.title.length > 0) ? item.title : (item.id || ""));
        if (item.tooltipDescription && item.tooltipDescription.length > 0) result += " • " + item.tooltipDescription;
        if (Config.options.tray?.showItemId && item.id) result += "\n[" + item.id + "]";
        return result;
    }

    // Pinning
    function pin(itemId) {
        if (!itemId) return;
        var pins = Config.options.tray.pinnedItems || [];
        if (pins.includes(itemId)) return;
        pins.push(itemId);
        Config.options.tray.pinnedItems = pins;
        root.requestUpdate();
    }
    function unpin(itemId) {
        if (!itemId) return;
        Config.options.tray.pinnedItems = (Config.options.tray.pinnedItems || []).filter(id => id !== itemId);
        root.requestUpdate();
    }
    function isPinned(itemId) {
        if (!itemId) return false;
        for (var i = 0; i < root.pinnedItems.length; i++) {
            if (root.pinnedItems[i] && root.pinnedItems[i].id === itemId)
                return true;
        }
        return false;
    }

    function togglePin(itemId) {
        if (!itemId) return;
        if (isPinned(itemId)) {
            unpin(itemId);
        } else {
            pin(itemId);
        }
    }
}
