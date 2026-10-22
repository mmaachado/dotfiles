import QtQuick
import qs.components
import qs.config
import qs.services

// Active window icon + vertical app name (like Caelestia's bar).
Column {
    id: root

    property real maxLength: 260
    readonly property var win: Bridge.activeWindow

    spacing: 8
    visible: win !== null

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: root.win ? Apps.iconFor(root.win) : ""
        size: 22
    }

    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        width: title.implicitHeight
        height: Math.min(title.implicitWidth, root.maxLength)

        StyledText {
            id: title
            anchors.centerIn: parent
            width: parent.height
            rotation: 90
            text: root.win ? Apps.nameFor(root.win) : ""
            color: Appearance.colors.textDim
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
