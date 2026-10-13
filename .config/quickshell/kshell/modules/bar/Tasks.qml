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

            Rectangle {
                anchors.fill: parent
                radius: Appearance.sizes.radiusSmall
                color: task.active ? Appearance.colors.primaryContainer : "transparent"
            }

            Icon {
                anchors.centerIn: parent
                name: Dock.icon(task.modelData)
                size: 26
                opacity: task.minimized ? 0.5 : 1
            }

            StateLayer {
                id: layer
                radius: Appearance.sizes.radiusSmall
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
                text: Dock.name(task.modelData) + (task.modelData.pinned ? "" : "  ·  right-click to pin")
                shown: tip.shown
            }

            HoverDelay {
                id: tip
                hovered: layer.containsMouse
            }
        }
    }
}
