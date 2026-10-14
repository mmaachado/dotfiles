import QtQuick
import qs.config

// Tooltip shown to the right of its parent (for the left bar).
Rectangle {
    id: root

    property string text
    property bool shown

    x: parent.width + 14
    anchors.verticalCenter: parent.verticalCenter
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
