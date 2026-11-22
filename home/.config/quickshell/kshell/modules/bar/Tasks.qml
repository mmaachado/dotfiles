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
            // Gap between the task and the pill's sides, across the bar.
            readonly property real inset: root.vertical ? (root.width - width) / 2 : (root.height - height) / 2
            // Corner radii at the start / end of the bar's axis.
            readonly property real startRadius: first ? root.radius : Appearance.sizes.radiusSmall
            readonly property real endRadius: last ? root.radius : Appearance.sizes.radiusSmall
            readonly property real tl: startRadius
            readonly property real tr: root.vertical ? startRadius : endRadius
            readonly property real bl: root.vertical ? endRadius : startRadius
            readonly property real br: endRadius
            readonly property int count: modelData.windows.length
            readonly property bool active: modelData.windows.some(w => w.active)
            readonly property bool minimized: count > 0 && modelData.windows.every(w => w.minimized)

            width: 38
            height: 38

            // Indicator on the screen-edge side: long bar = focused, dots =
            // number of windows.
            Grid {
                readonly property string edge: Appearance.barPosition
                x: edge === "left" ? -6 : edge === "right" ? parent.width + 3 : (parent.width - width) / 2
                y: edge === "top" ? -6 : edge === "bottom" ? parent.height + 3 : (parent.height - height) / 2
                columns: root.vertical ? 1 : 99
                spacing: 3

                Repeater {
                    model: task.active ? 1 : Math.min(task.count, 3)

                    Rectangle {
                        property real length: task.active ? 20 : 4
                        width: root.vertical ? 3 : length
                        height: root.vertical ? length : 3
                        radius: 2
                        color: task.minimized ? Appearance.colors.textFaint : Appearance.colors.primary

                        Behavior on length {
                            NumberAnimation { duration: Appearance.anim.normal; easing.type: Easing.OutCubic }
                        }
                    }
                }
            }

            Item {
                id: highlight
                anchors.fill: parent
                // The first and last reach to the pill's ends along the bar,
                // and across it to its sides.
                readonly property real startMargin: task.first ? -root.padding : 0
                readonly property real endMargin: task.last ? -root.padding : 0
                readonly property real sideMargin: task.first || task.last ? -task.inset : 0
                anchors.topMargin: root.vertical ? startMargin : sideMargin
                anchors.bottomMargin: root.vertical ? endMargin : sideMargin
                anchors.leftMargin: root.vertical ? sideMargin : startMargin
                anchors.rightMargin: root.vertical ? sideMargin : endMargin

                Rectangle {
                    anchors.fill: parent
                    topLeftRadius: task.tl
                    topRightRadius: task.tr
                    bottomLeftRadius: task.bl
                    bottomRightRadius: task.br
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
                topLeftRadius: task.tl
                topRightRadius: task.tr
                bottomLeftRadius: task.bl
                bottomRightRadius: task.br
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
