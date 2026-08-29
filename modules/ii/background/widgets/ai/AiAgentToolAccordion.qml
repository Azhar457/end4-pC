import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    required property string toolName
    required property var toolInput
    required property string toolResult
    required property bool isRunning
    required property bool isError

    property bool expanded: false

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + 16
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: isError ? Appearance.colors.colError : (isRunning ? Appearance.colors.colPrimary : Appearance.colors.colLayer0Border)

    Behavior on border.color {
        ColorAnimation { duration: 150 }
    }

    ColumnLayout {
        id: mainLayout
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 8
        }
        spacing: 6

        // Header Row
        MouseArea {
            Layout.fillWidth: true
            implicitHeight: headerRow.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: root.expanded = !root.expanded

            RowLayout {
                id: headerRow
                anchors.fill: parent
                spacing: 8

                // Tool Icon
                MaterialSymbol {
                    iconSize: 18
                    color: isError ? Appearance.colors.colError : (isRunning ? Appearance.colors.colPrimary : Appearance.colors.colOnLayer0)
                    text: {
                        if (toolName === "bash") return "terminal";
                        if (toolName.startsWith("file")) return "description";
                        if (toolName.startsWith("web")) return "public";
                        if (toolName.startsWith("hyprland")) return "desktop_windows";
                        return "handyman";
                    }
                }

                // Tool Name & Status
                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colOnLayer0
                    text: `${toolName} ${isRunning ? "..." : (isError ? "failed" : "executed")}`
                    elide: Text.ElideRight
                }

                // Status Badge
                Rectangle {
                    implicitWidth: statusText.implicitWidth + 12
                    implicitHeight: 20
                    radius: Appearance.rounding.full
                    color: isError ? Appearance.colors.colErrorContainer : (isRunning ? Appearance.colors.colPrimaryContainer : Appearance.colors.colSecondaryContainer)

                    StyledText {
                        id: statusText
                        anchors.centerIn: parent
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Medium
                        color: isError ? Appearance.colors.colOnErrorContainer : (isRunning ? Appearance.colors.colOnPrimaryContainer : Appearance.colors.colOnSecondaryContainer)
                        text: isRunning ? "Running" : (isError ? "Error" : "Done")
                    }
                }

                // Chevron Toggle
                MaterialSymbol {
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                    text: root.expanded ? "expand_less" : "expand_more"
                }
            }
        }

        // Details Container (Collapsible)
        ColumnLayout {
            id: detailsLayout
            Layout.fillWidth: true
            visible: root.expanded
            spacing: 6

            // Input / Command
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: inputCol.implicitHeight + 12
                radius: Appearance.rounding.smaller
                color: "#1e293b"

                ColumnLayout {
                    id: inputCol
                    anchors {
                        left: parent.left
                        right: parent.right
                        top: parent.top
                        margins: 6
                    }
                    spacing: 2

                    StyledText {
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.weight: Font.Bold
                        color: "#38bdf8"
                        text: "Command / Input:"
                    }

                    StyledText {
                        Layout.fillWidth: true
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        color: "#f1f5f9"
                        wrapMode: Text.WrapAnywhere
                        text: JSON.stringify(toolInput, null, 2)
                    }
                }
            }

            // Output / Result
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: Math.min(200, outputText.implicitHeight + 16)
                radius: Appearance.rounding.smaller
                color: "#0f172a"
                clip: true

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 6
                    contentWidth: width
                    contentHeight: outputText.height
                    clip: true

                    StyledText {
                        id: outputText
                        width: parent.width
                        font.pixelSize: Appearance.font.pixelSize.smaller
                        font.family: Appearance.font.family.monospace
                        color: isError ? "#f87171" : "#4ade80"
                        wrapMode: Text.WrapAnywhere
                        text: toolResult.length > 0 ? toolResult : (isRunning ? "Executing..." : "(No output)")
                    }
                }
            }
        }
    }
}
