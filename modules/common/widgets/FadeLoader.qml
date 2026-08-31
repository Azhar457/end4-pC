import QtQuick

import qs.modules.common

Loader {
    id: root
    property bool shown: true
    property alias fade: opacityBehavior.enabled
    property alias animation: opacityBehavior.animation
    opacity: shown ? 1 : 0
    visible: opacity > 0
    // Drive `active` from the `shown` intent, not the animated opacity.
    // Tying active to opacity > 0 tears the widget's QML component down
    // on any opacity dip — e.g. a sibling widget being focused or a
    // layout transition — which is what made widgets appear to "close on
    // their own" the moment the user used another widget. Keeping the
    // component alive while `shown` is true preserves focus, scroll
    // position, and avoids the unload/reload flicker.
    active: shown

    Behavior on opacity {
        id: opacityBehavior
        animation: Appearance.animation.elementMoveFast.numberAnimation.createObject(this)
    }
}
