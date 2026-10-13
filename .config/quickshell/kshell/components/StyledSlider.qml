import QtQuick
import qs.config

Item {
    id: root

    property real value: 0      // 0..1
    property string icon: ""
    signal moved(real value)
    signal iconClicked

    implicitHeight: 36

    Rectangle {
        id: track
        anchors.fill: parent
        radius: height / 2
        color: Appearance.colors.surfaceHigh

        Rectangle {
            width: Math.max(height, parent.width * Math.min(1, root.value))
            height: parent.height
            radius: height / 2
            color: Appearance.colors.primary

            Behavior on width {
                enabled: !drag.pressed
                NumberAnimation { duration: Appearance.anim.fast }
            }
        }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function update(x: real): void {
            root.moved(Math.max(0, Math.min(1, x / width)));
        }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }

    Icon {
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 18
        color: Appearance.colors.onPrimary

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }
}
