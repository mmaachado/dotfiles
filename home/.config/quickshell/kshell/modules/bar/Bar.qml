import QtQuick
import qs.components
import qs.config
import qs.services

Item {
    id: root

    required property string screenName

    width: Appearance.sizes.barWidth

    Column {
        id: top
        anchors.top: parent.top
        anchors.topMargin: 14
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12

        Workspaces {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        ActiveWindow {
            anchors.horizontalCenter: parent.horizontalCenter
            maxLength: Math.max(0, middle.y - top.y - y - 40)
            visible: Bridge.activeWindow !== null && maxLength > 40
        }
    }

    // Tasks are centred in the bar, like Caelestia centres its workspaces.
    Item {
        id: middle
        anchors.verticalCenter: parent.verticalCenter
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width
        height: Math.min(tasks.implicitHeight, root.height * 0.6)
        clip: tasks.implicitHeight > height

        Tasks {
            id: tasks
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    Column {
        id: bottom
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 10

        Tray {
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Status {
            anchors.horizontalCenter: parent.horizontalCenter
            screenName: root.screenName
        }

        IconButton {
            anchors.horizontalCenter: parent.horizontalCenter
            icon: "system-shutdown-symbolic"
            iconSize: 20
            tooltip: "Power"
            active: Visibilities.session
            onClicked: Visibilities.toggle("session", root.screenName)
        }
    }
}
