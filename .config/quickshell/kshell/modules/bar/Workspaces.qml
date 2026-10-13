import QtQuick
import qs.components
import qs.config
import qs.services

// KWin virtual desktops. Click to switch, scroll to cycle.
Pill {
    id: root

    spacing: 6
    padding: 10

    Repeater {
        model: Bridge.desktops

        Item {
            id: ws
            required property var modelData
            required property int index
            readonly property bool current: modelData.id === Bridge.current
            readonly property bool occupied: Bridge.hasWindows(modelData.id)

            width: 24
            height: current ? 40 : 24

            Behavior on height {
                NumberAnimation {
                    duration: Appearance.anim.normal
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Appearance.anim.standard
                }
            }

            Rectangle {
                anchors.fill: parent
                radius: width / 2
                color: ws.current ? Appearance.colors.primary : "transparent"

                Behavior on color {
                    ColorAnimation { duration: Appearance.anim.normal }
                }
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
