import QtQuick
import qs.components
import qs.config
import qs.services

// Pinned apps + open windows on the current desktop (replaces Plasma's dock).
// Left click: launch / focus / minimise / cycle windows. Middle click: new
// instance. Right click: pin or unpin.
Pill {
    id: root

    spacing: 2
    visible: Dock.groups.length > 0

    Repeater {
        model: Dock.groups

        Item {
            id: task
            required property var modelData
            required property int index
            // The first and last highlights reach out to the pill's rounded
            // ends instead of leaving a gap inside them.
            readonly property bool first: index === 0
            readonly property bool last: index === Dock.groups.length - 1
            readonly property real inset: (root.width - width) / 2
            readonly property real topRadius: first ? root.radius : Appearance.sizes.radiusSmall
            readonly property real bottomRadius: last ? root.radius : Appearance.sizes.radiusSmall
            readonly property int count: modelData.windows.length
            readonly property bool active: modelData.windows.some(w => w.active)
            readonly property bool minimized: count > 0 && modelData.windows.every(w => w.minimized)

            width: 38
            height: 38

            // Indicator: long bar = focused, dots = number of windows.
            Column {
                anchors.left: parent.left
                anchors.leftMargin: -6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 3

                Repeater {
                    model: task.active ? 1 : Math.min(task.count, 3)

                    Rectangle {
                        width: 3
                        height: task.active ? 20 : 4
                        radius: 2
                        color: task.minimized ? Appearance.colors.textFaint : Appearance.colors.primary

                        Behavior on height {
                            NumberAnimation { duration: Appearance.anim.normal; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Item {
                id: highlight
                anchors.fill: parent
                anchors.topMargin: task.first ? -root.padding : 0
                anchors.bottomMargin: task.last ? -root.padding : 0
                anchors.leftMargin: task.first || task.last ? -task.inset : 0
                anchors.rightMargin: task.first || task.last ? -task.inset : 0

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: task.topRadius
                    topRightRadius: task.topRadius
                    bottomLeftRadius: task.bottomRadius
                    bottomRightRadius: task.bottomRadius
                    color: task.active ? Appearance.colors.primaryContainer : "transparent"
                }
            }

            Icon {
                anchors.centerIn: parent
                name: Dock.icon(task.modelData)
                size: 26
                opacity: task.minimized ? 0.5 : 1
            }

            StateLayer {
                id: layer
                parent: highlight
                topRadius: task.topRadius
                bottomRadius: task.bottomRadius
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.MiddleButton)
                        Dock.launch(task.modelData);
                    else if (mouse.button === Qt.RightButton)
                        Dock.togglePin(task.modelData.id);
                    else
                        Dock.activate(task.modelData);
                }
            }

            Tooltip {
                text: Dock.name(task.modelData) + (task.modelData.pinned ? "  ·  right-click to unpin" : "  ·  right-click to pin")
                shown: tip.shown
            }

            HoverDelay {
                id: tip
                hovered: layer.containsMouse
            }
        }
    }
}
