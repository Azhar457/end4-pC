import QtQuick
import QtQuick.Layouts
import qs.modules.common
import qs.modules.common.widgets

StyledFlickable {
    id: root
    property real baseWidth: 600
    property bool forceWidth: false
    property real bottomContentPadding: Config.options.settings.style === "minimal" ? 40 : 90

    default property alias data: contentColumn.data

    clip: true
    contentHeight: contentColumn.implicitHeight + root.bottomContentPadding // Add some padding at the bottom
    implicitWidth: contentColumn.implicitWidth
    
    function highlightItem(item) {
        if (!item) return;
        let pos = item.mapToItem(contentColumn, 0, 0);
        highlightOverlay.x = pos.x - 4;
        highlightOverlay.y = pos.y - 4;
        highlightOverlay.width = item.width + 8;
        highlightOverlay.height = item.height + 8;
        highlightAnim.restart();
    }

    ColumnLayout {
        id: contentColumn
        anchors {
            left: parent.left
            right: parent.right
            top: parent.top
            margins: 20
        }
        spacing: 30

        Rectangle {
            id: highlightOverlay
            z: 999
            visible: opacity > 0
            opacity: 0
            color: "transparent"
            border.width: 2
            border.color: Appearance.colors.colPrimary
            radius: Appearance.rounding.normal

            NumberAnimation {
                id: highlightAnim
                target: highlightOverlay
                property: "opacity"
                from: 1.0
                to: 0.0
                duration: 1500
                easing.type: Easing.OutCubic
            }
        }
    }

}
