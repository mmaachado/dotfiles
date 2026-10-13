import QtQuick
import qs.config

// Hover/press highlight + click handling; place inside any rounded item.
MouseArea {
    id: root

    property color tint: Appearance.colors.text
    property real radius: parent?.radius ?? 0

    anchors.fill: parent
    hoverEnabled: true
    cursorShape: enabled ? Qt.PointingHandCursor : Qt.ArrowCursor

    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: root.tint
        opacity: !root.enabled ? 0 : root.pressed ? 0.16 : root.containsMouse ? 0.08 : 0

        Behavior on opacity {
            NumberAnimation { duration: Appearance.anim.fast }
        }
    }
}
