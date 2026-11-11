import QtQuick
import qs.components
import qs.config
import qs.services

// KWin virtual desktops. Click to switch, scroll to cycle.
//
// The highlight is one pill that travels between desktops. Its leading edge
// runs on a quick spring and its trailing edge on a slow one, so it stretches
// toward the new desktop and then catches up (after shoji-bar-4's bar).
Pill {
    id: root

    spacing: 6
    padding: 10

    readonly property Item currentCell: cells.itemAt(Math.max(0, Bridge.currentIndex))
    readonly property real cellTop: root.column.y + (currentCell?.y ?? 0)
    readonly property real cellBottom: cellTop + (currentCell?.height ?? 0)
    property bool movingDown: true
    readonly property var lead: [900, 0.7]
    readonly property var trail: [260, 0.85]

    Connections {
        target: Bridge
        function onCurrentIndexChanged() {
            const y = root.column.y + (cells.itemAt(Math.max(0, Bridge.currentIndex))?.y ?? 0);
            root.movingDown = y >= top.value;
        }
    }

    Spring {
        id: top
        target: root.cellTop
        preset: root.movingDown ? root.trail : root.lead
        epsilon: 0.05
    }
    Spring {
        id: bottom
        target: root.cellBottom
        preset: root.movingDown ? root.lead : root.trail
        epsilon: 0.05
    }

    Rectangle {
        parent: root // not into the column: it floats behind the cells
        visible: Bridge.currentIndex >= 0
        x: root.column.x
        y: top.value
        width: root.column.width
        height: Math.max(width, bottom.value - top.value)
        radius: width / 2
        color: Appearance.colors.primary
    }

    Repeater {
        id: cells
        model: Bridge.desktops

        Item {
            id: ws
            required property var modelData
            required property int index
            readonly property bool current: modelData.id === Bridge.current
            readonly property bool occupied: Bridge.hasWindows(modelData.id)

            width: 24
            height: heightSpring.value

            Spring {
                id: heightSpring
                target: ws.current ? 40 : 24
                preset: Appearance.spring.defaultSpatial
                epsilon: 0.05
            }

            StyledText {
                anchors.centerIn: parent
                text: ws.index + 1
                font.pointSize: Appearance.font.small
                font.bold: ws.current
                color: ws.current ? Appearance.colors.onPrimary : ws.occupied ? Appearance.colors.text : Appearance.colors.textFaint
            }

            StateLayer {
                id: wsLayer
                radius: width / 2
                onClicked: Bridge.switchDesktop(ws.modelData.id)
            }

            Tooltip {
                text: ws.modelData.name
                shown: tip.shown
            }

            HoverDelay {
                id: tip
                hovered: wsLayer.containsMouse
            }
        }
    }

    WheelHandler {
        parent: root
        acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
        onWheel: event => Bridge.cycleDesktop(event.angleDelta.y > 0 ? -1 : 1)
    }
}
