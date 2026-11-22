import QtQuick
import qs.components
import qs.config
import qs.services

// The bar, on whichever screen edge Appearance.barPosition says. Vertical
// (left/right): desktops and the active window at the top, apps centred,
// then power, settings, status and the tray down at the bottom. Horizontal (top/bottom): split
// in two around a gap in the middle (`centerGap`) for the notch or the
// launcher: desktops and apps on the left, tray to power on the right.
Item {
    id: root

    required property string screenName
    // Room to leave free in the middle of a horizontal bar.
    property real centerGap: 0
    readonly property bool vertical: Appearance.barVertical

    implicitWidth: vertical ? Appearance.sizes.barWidth : 0
    implicitHeight: vertical ? 0 : Appearance.sizes.barWidth

    component SettingsButton: IconButton {
        icon: "configure-symbolic"
        iconSize: 18
        tooltip: "Settings"
        active: Settings.open
        onClicked: Settings.toggle()
    }

    component PowerButton: IconButton {
        icon: "system-shutdown-symbolic"
        iconSize: 20
        tooltip: "Power"
        active: Visibilities.session
        onClicked: Visibilities.toggle("session", root.screenName)
    }

    // Only the layout in use exists, so modules aren't instantiated twice.
    Loader {
        anchors.fill: parent
        sourceComponent: root.vertical ? verticalLayout : horizontalLayout
    }

    Component {
        id: verticalLayout

        Item {
            // Explicit: the Loader doesn't always resize an item it created
            // while the bar had the other orientation.
            anchors.fill: parent
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
                height: Math.min(tasks.implicitHeight, parent.height * 0.6)
                clip: tasks.implicitHeight > height

                Tasks {
                    id: tasks
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }

            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 10
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10

                PowerButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                SettingsButton {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
                Status {
                    anchors.horizontalCenter: parent.horizontalCenter
                    screenName: root.screenName
                }
                Tray {
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    Component {
        id: horizontalLayout

        Item {
            id: hbar
            anchors.fill: parent
            // Each half's length, up to the gap in the middle.
            readonly property real half: Math.max(0, (width - root.centerGap) / 2 - 14)

            Row {
                id: start
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                Workspaces {
                    id: desktops
                    anchors.verticalCenter: parent.verticalCenter
                }

                Item {
                    id: apps
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(tasks.implicitWidth, Math.max(0, hbar.half - (desktops.visible ? desktops.width + start.spacing : 0)))
                    height: tasks.implicitHeight
                    clip: tasks.implicitWidth > width

                    Tasks {
                        id: tasks
                    }
                }

                ActiveWindow {
                    anchors.verticalCenter: parent.verticalCenter
                    maxLength: Math.max(0, hbar.half - apps.x - apps.width - start.spacing - 30)
                    visible: Bridge.activeWindow !== null && maxLength > 60
                }
            }

            Row {
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                spacing: 10

                Tray {
                    anchors.verticalCenter: parent.verticalCenter
                }
                Status {
                    anchors.verticalCenter: parent.verticalCenter
                    screenName: root.screenName
                }
                SettingsButton {
                    anchors.verticalCenter: parent.verticalCenter
                }
                PowerButton {
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }
}
