pragma Singleton
import qs
import qs.modules.common
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
 * System updates service. Currently only supports Arch.
 */
Singleton {
    id: root

    property bool available: false
    property alias checking: checkUpdatesProc.running
    property int count: 0
    property int systemCount: 0
    property int flatpakCount: 0

    readonly property bool updateAdvised: available && count > Config.options.updates.adviseUpdateThreshold
    readonly property bool updateStronglyAdvised: available && count > Config.options.updates.stronglyAdviseUpdateThreshold

    function load() {}
    function refresh() {
        if (!available) return;
        print("[Updates] Checking for system updates")
        checkUpdatesProc.running = true;
    }

    Timer {
        interval: Config.options.updates.checkInterval * 60 * 1000
        repeat: true
        running: Config.ready && Config.options.updates.enableCheck
        onTriggered: {
            print("[Updates] Periodic update check due")
            root.refresh();
        }
    }

    Process {
        id: checkAvailabilityProc
        running: Config.ready && Config.options.updates.enableCheck
        command: ["bash", "-c", "command -v dnf || command -v checkupdates || command -v apt"]
        onExited: (exitCode, exitStatus) => {
            root.available = (exitCode === 0);
            root.refresh();
        }
    }

    Process {
        id: checkUpdatesProc
        command: [`${Directories.scriptPath}/system/check_updates.sh`]
        stdout: StdioCollector {
            onStreamFinished: {
                // Script emits 3 lines: system=N  flatpak=N  total=N
                let sys = 0, fp = 0, tot = 0;
                for (const line of text.split("\n")) {
                    const m = line.match(/^(system|flatpak|total)\s*=\s*(\d+)/);
                    if (!m) continue;
                    if (m[1] === "system")  sys = parseInt(m[2]) || 0;
                    if (m[1] === "flatpak") fp  = parseInt(m[2]) || 0;
                    if (m[1] === "total")   tot = parseInt(m[2]) || 0;
                }
                root.systemCount  = sys;
                root.flatpakCount = fp;
                root.count        = tot;
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.count = 0;
                root.systemCount = 0;
                root.flatpakCount = 0;
            }
        }
    }
}
