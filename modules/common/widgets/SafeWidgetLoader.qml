pragma ComponentBehavior: Bound

import QtQuick
import qs.modules.common

Loader {
    id: root

    property string widgetName: ""
    readonly property bool hasError: status === Loader.Error

    visible: status === Loader.Ready && (item?.visible ?? true)

    onStatusChanged: {
        if (status === Loader.Error) {
            console.warn(`[SafeWidgetLoader] Failed to load widget: ${root.source}`);
        }
    }
}
