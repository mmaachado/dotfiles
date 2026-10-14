import QtQuick
import qs.config

Rectangle {
    id: root

    property alias icon: ico.name
    property int iconSize: Appearance.sizes.iconBar
    property bool active: false
    property bool tintIcon: true
    property string tooltip: ""
    readonly property alias hovered: layer.containsMouse

    signal clicked(var mouse)

    implicitWidth: iconSize + 16
    implicitHeight: iconSize + 16
    radius: Math.min(width, height) / 2
    color: active ? Appearance.colors.primary : "transparent"

    Behavior on color {
        ColorAnimation { duration: Appearance.anim.fast }
    }

    Icon {
        id: ico
        anchors.centerIn: parent
        size: root.iconSize
        color: root.active ? Appearance.colors.onPrimary : (root.tintIcon ? Appearance.colors.text : "transparent")
    }

    Tooltip {
        text: root.tooltip
        shown: tipDelay.shown
    }

    HoverDelay {
        id: tipDelay
        hovered: layer.containsMouse
    }

    StateLayer {
        id: layer
        tint: root.active ? Appearance.colors.onPrimary : Appearance.colors.text
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onClicked: mouse => root.clicked(mouse)
    }
}
