import QtQuick
import qs.config

// Tooltip that opens away from the screen edge its parent sits on (the
// bar's edge unless set), so it always points into the screen.
Rectangle {
    id: root

    property string text
    property bool shown
    property string edge: Appearance.barPosition

    x: edge === "left" ? parent.width + 14 : edge === "right" ? -width - 14 : (parent.width - width) / 2
    y: edge === "top" ? parent.height + 14 : edge === "bottom" ? -height - 14 : (parent.height - height) / 2
    z: 100
    implicitWidth: label.implicitWidth + 20
    implicitHeight: label.implicitHeight + 12
    radius: Appearance.sizes.radiusSmall
    color: Appearance.colors.surfaceHighest
    opacity: shown && text !== "" ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation { duration: Appearance.anim.fast }
    }

    StyledText {
        id: label
        anchors.centerIn: parent
        text: root.text
        width: Math.min(implicitWidth, 360)
    }
}
