import QtQuick
import qs.config

// On/off switch. Emits toggled(); the owner updates `checked`.
Rectangle {
    id: root

    property bool checked
    signal toggled

    implicitWidth: 46
    implicitHeight: 26
    radius: height / 2
    color: checked ? Appearance.colors.primary : Appearance.colors.surfaceHigh
    border.width: checked ? 0 : 1
    border.color: Appearance.colors.outline

    Behavior on color {
        ColorAnimation { duration: Appearance.anim.fast }
    }

    Rectangle {
        width: root.height - 8
        height: width
        radius: width / 2
        anchors.verticalCenter: parent.verticalCenter
        x: root.checked ? root.width - width - 4 : 4
        color: root.checked ? Appearance.colors.onPrimary : Appearance.colors.textDim

        Behavior on x {
            NumberAnimation { duration: Appearance.anim.fast; easing.type: Easing.OutCubic }
        }
    }

    StateLayer {
        tint: root.checked ? Appearance.colors.onPrimary : Appearance.colors.text
        onClicked: root.toggled()
    }
}
