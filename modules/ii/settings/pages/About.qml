import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Quickshell.Io
import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions

ContentPage {
    forceWidth: true
    bottomContentPadding: 35
    property bool isMinimal: Config.options.settings.style === "minimal"

    function runSystemUpdate() {
        Quickshell.execDetached([
            "kitty", "--hold",
            "bash", "-c",
            "sudo dnf upgrade --refresh"
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    function runUpdateDots() {
        // Safe in-place update of the end4-pC fork. Replaces the previous
        // destructive `git clone + mv + rm -rf` flow that silently
        // destroyed the user's working tree on every click (uncommitted
        // edits, untracked files like the agent / rice-doctor / custom
        // wallpapers, and unpushed local commits were all lost). The new
        // flow lives in scripts/system/update-fork.sh: it stashes local
        // uncommitted + untracked work, fast-forwards or rebases onto
        // origin/<branch>, pops the stash, and only then restarts qs.
        // It never deletes the working tree, so the user's data survives
        // every "Update Dots" click.
        const scriptPath = `${Directories.scriptPath}/system/update-fork.sh`;
        Quickshell.execDetached(["kitty", "--hold", "bash", "-c",
            `REPO_DIR='$HOME/.config/quickshell/end4-pC' '${scriptPath}'`
        ])
        Qt.callLater(() => GlobalStates.settingsOpen = false)
    }

    Rectangle {
        Layout.fillWidth: true
        Layout.preferredHeight: 156 
        Layout.topMargin: !isMinimal ? 35 : 4
        Layout.leftMargin: !isMinimal ? 16 : 0
        Layout.rightMargin: !isMinimal ? 16 : 0

        radius: 24
        color: Appearance.colors.colLayer1

        RowLayout {
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 24
            spacing: 24

            Rectangle {
                Layout.alignment: Qt.AlignVCenter
                implicitWidth: 110
                implicitHeight: 110
                radius: 20
                color: ColorUtils.transparentize(Appearance.colors.colPrimary, 0.9)

                IconImage {
                    anchors.centerIn: parent
                    implicitWidth: 72
                    implicitHeight: 72
                    source: "file://" + Directories.assetsPath + "/icons/" + (SystemInfo.distroIcon || "fedora-symbolic") + ".svg"
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignVCenter
                spacing: 4

                StyledText {
                    Layout.fillWidth: true
                    text: SystemInfo.distroName
                    font.pixelSize: Appearance.font.pixelSize.hugeass
                    font.weight: Font.ExtraBold
                    color: Appearance.colors.colOnSurface
                    elide: Text.ElideRight
                }

                StyledText {
                    Layout.fillWidth: true
                    text: "Kernel " + (SystemInfo.kernelVersion || "Loading...")
                    font.pixelSize: Appearance.font.pixelSize.normal
                    font.weight: Font.Medium
                    color: Appearance.colors.colSubtext
                    elide: Text.ElideRight
                }

                Row {
                    id: colorRow
                    spacing: -6

                    Repeater {
                        model: [
                            Appearance.m3colors.m3primary,
                            Appearance.m3colors.m3secondary,
                            Appearance.m3colors.m3tertiary,
                            Appearance.m3colors.m3error,
                            Appearance.m3colors.m3primaryContainer,
                            Appearance.m3colors.m3secondaryContainer,
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 28
                            height: 28
                            radius: width / 2
                            color: modelData
                            z: index
                            border.width: 2
                            border.color: Appearance.colors.colLayer1
                        }
                    }
                }
            }
            RowLayout {
                Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                spacing: 8
                RippleButton {
                    buttonText: Translation.tr("Update Dots")
                    buttonRadius: Appearance.rounding.full
                    colBackground: Appearance.colors.colPrimaryContainer
                    colBackgroundHover: Appearance.colors.colPrimaryContainerHover
                    Layout.preferredHeight: 44
                    downAction: () => runUpdateDots()
                    contentItem: StyledText {
                        text: parent.buttonText
                        horizontalAlignment: Text.AlignHCenter
                        leftPadding: 10
                        rightPadding: 10
                    }
                }
            }
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: !isMinimal ? 0 : -8
        spacing: 8

        RowLayout { //This is not in the grid because I was planning to do something else.
            Layout.fillWidth: true
            spacing: 8

            AboutCard {
                icon: "planner_review"
                iconShape: MaterialShape.Shape.Pentagon
                label: "CPU"
                value: SystemInfo.cpu || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "monitor"
                iconShape: MaterialShape.Shape.ClamShell
                label: "GPU"
                value: SystemInfo.gpu || "N/A"
                Layout.fillWidth: true
            }
        }

        GridLayout {
            columns: 2
            Layout.fillWidth: true
            rowSpacing: 8
            columnSpacing: 8

            AboutCard {
                icon: "memory"
                label: "Memory"
                value: SystemInfo.memory || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "storage"
                iconShape: MaterialShape.Shape.Cookie6Sided
                label: "Disk"
                value: SystemInfo.disk || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                visible: !isMinimal
                icon: "terminal"
                label: "Shell"
                iconShape: MaterialShape.Shape.Gem
                value: SystemInfo.shell || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "package_2"
                label: "Packages"
                iconShape: MaterialShape.Shape.Sunny
                value: SystemInfo.packages || "Loading..."
                Layout.fillWidth: true
            }

            AboutCard {
                icon: "update"
                label: "Updates"
                iconShape: MaterialShape.Shape.Cookie9Sided
                value: Updates.checking ? "Checking..." : (Updates.count === 0 ? "Up to date" : `${Updates.count}`)
                Layout.fillWidth: true
                clickAction: () => {
                    runSystemUpdate()
                }
            }

            AboutCard {
                visible: !isMinimal
                icon: "timelapse"
                label: "Uptime"
                iconShape: MaterialShape.Shape.Cookie12Sided
                value: DateTime.uptime || "Loading..."
                Layout.fillWidth: true
            }
        }
    }
}