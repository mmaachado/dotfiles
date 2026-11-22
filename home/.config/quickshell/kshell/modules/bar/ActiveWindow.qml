import QtQuick
import qs.components
import qs.config
import qs.services

// Active window icon + app name: the name runs down a vertical bar (like
// Caelestia's) and sits beside the icon in a horizontal one.
Grid {
    id: root

    property real maxLength: 260
    readonly property var win: Bridge.activeWindow
    readonly property bool vertical: Appearance.barVertical

    columns: vertical ? 1 : 99
    spacing: 8
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    visible: win !== null

    Icon {
        name: root.win ? Apps.iconFor(root.win) : ""
        size: 22
    }

    Item {
        readonly property real length: Math.min(title.implicitWidth, root.maxLength)
        width: root.vertical ? title.implicitHeight : length
        height: root.vertical ? length : title.implicitHeight

        StyledText {
            id: title
            anchors.centerIn: parent
            width: root.vertical ? parent.height : parent.length
            rotation: root.vertical ? 90 : 0
            text: root.win ? Apps.nameFor(root.win) : ""
            color: Appearance.colors.textDim
            horizontalAlignment: Text.AlignHCenter
        }
    }
}
