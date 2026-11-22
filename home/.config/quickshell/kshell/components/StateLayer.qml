import QtQuick
import qs.config

// Hover/press highlight + click handling; place inside any rounded item.
MouseArea {
    id: root

    property color tint: Appearance.colors.text
    property real radius: parent?.radius ?? 0
    property real topRadius: radius
    property real bottomRadius: radius
    property real topLeftRadius: topRadius
    property real topRightRadius: topRadius
    property real bottomLeftRadius: bottomRadius
    property real bottomRightRadius: bottomRadius

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        topLeftRadius: root.topLeftRadius
        topRightRadius: root.topRightRadius
        bottomLeftRadius: root.bottomLeftRadius
        bottomRightRadius: root.bottomRightRadius
        color: root.tint
        opacity: !root.enabled ? 0 : root.pressed ? 0.16 : root.containsMouse ? 0.08 : 0

        Behavior on opacity {
            NumberAnimation { duration: Appearance.anim.fast }
        }
    }
}
