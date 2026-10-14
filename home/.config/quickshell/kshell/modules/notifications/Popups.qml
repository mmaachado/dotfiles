import QtQuick
import qs.config
import qs.services

// Stack of notification popups in the top-right corner of the frame.
Column {
    id: root

    spacing: 10
    width: 380

    move: Transition {
        NumberAnimation { properties: "y"; duration: Appearance.anim.normal; easing.type: Easing.OutCubic }
    }

    Repeater {
        model: Notifs.popups.slice(0, 5)

        NotifCard {
            id: card
            required property var modelData
            notif: modelData
            popup: true

            x: 0
            opacity: 1
            Component.onCompleted: { x = 420; opacity = 0; x = 0; opacity = 1; }

            Behavior on x {
                NumberAnimation { duration: Appearance.anim.slow; easing.type: Easing.BezierSpline; easing.bezierCurve: Appearance.anim.enter }
            }
            Behavior on opacity {
                NumberAnimation { duration: Appearance.anim.normal }
            }
        }
    }
}
