import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs
import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets

Rectangle {
    id: root

    required property string thinkingText
    required property bool isThinking

    property bool expanded: false

    Layout.fillWidth: true
    implicitHeight: mainLayout.implicitHeight + 12
    radius: Appearance.rounding.small
    color: Appearance.colors.colLayer1
    border.width: 1
    border.color: isThinking ? Appearance.colors.colTertiary : Appearance.colors.colLayer0Border

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

                MaterialSymbol {
                    iconSize: 18
                    color: Appearance.colors.colTertiary
                    text: "psychology"
                }

                StyledText {
                    Layout.fillWidth: true
                    font.pixelSize: Appearance.font.pixelSize.small
                    font.weight: Font.DemiBold
                    color: Appearance.colors.colTertiary
                    text: isThinking ? "Thinking Process..." : "Thought Process"
                }

                MaterialSymbol {
                    iconSize: 16
                    color: Appearance.colors.colSubtext
                    text: root.expanded ? "expand_less" : "expand_more"
                }
            }
        }

        // Expanded Thinking Text
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: Math.min(180, thinkText.implicitHeight + 16)
            visible: root.expanded
            radius: Appearance.rounding.small
            color: "#1e1e2e"
            clip: true

            Flickable {
                anchors.fill: parent
                anchors.margins: 8
                contentWidth: width
                contentHeight: thinkText.height
                clip: true

                StyledText {
                    id: thinkText
                    width: parent.width
                    font.pixelSize: Appearance.font.pixelSize.smaller
                    font.family: Appearance.font.family.monospace
                    color: "#cdd6f4"
                    wrapMode: Text.WrapAnywhere
                    text: root.thinkingText.replace(/<\/?think>/g, "").trim()
                }
            }
        }
    }
}
