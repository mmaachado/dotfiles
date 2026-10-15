import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import qs.components
import qs.config
import qs.services

Rectangle {
    id: root

    required property Notification notif
    property bool popup: false

    readonly property string image: notif.image || ""
    readonly property string appIcon: notif.appIcon || notif.desktopEntry || ""

    implicitWidth: 380
    implicitHeight: content.implicitHeight + 24
    radius: Appearance.sizes.radius
    color: popup ? Appearance.colors.popup : Appearance.colors.surface
    border.width: notif.urgency === NotificationUrgency.Critical ? 2 : 0
    border.color: Appearance.colors.error

    HoverHandler { id: hover }

    // Popup lifetime (paused while hovered).
    Timer {
        running: root.popup && !hover.hovered && root.notif.urgency !== NotificationUrgency.Critical
        interval: {
            const t = root.notif.expireTimeout;
            return t <= 0 ? 6000 : t < 100 ? t * 1000 : t;
        }
        onTriggered: Notifs.dismissPopup(root.notif)
    }

    TapHandler {
        onTapped: {
            const def = root.notif.actions.find(a => a.identifier === "default");
            if (def) {
                def.invoke();
            } else if (root.popup) {
                Notifs.dismissPopup(root.notif);
            }
        }
    }

    Row {
        id: content
        x: 12
        y: 12
        width: parent.width - 24
        spacing: 12

        Item {
            width: 40
            height: 40

            Image {
                anchors.fill: parent
                visible: root.image !== ""
                source: root.image
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize: Qt.size(80, 80)
            }

            Icon {
                anchors.centerIn: parent
                visible: root.image === ""
                name: root.appIcon
                fallback: "preferences-desktop-notification"
                size: 32
            }
        }

        Column {
            width: parent.width - 52
            spacing: 4

            Item {
                width: parent.width
                height: appName.implicitHeight

                StyledText {
                    id: appName
                    anchors.left: parent.left
                    anchors.right: closeBtn.left
                    text: root.notif.appName
                    color: Appearance.colors.textDim
                    font.pointSize: Appearance.font.small
                }

                Icon {
                    id: closeBtn
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    name: "window-close-symbolic"
                    size: 14
                    color: Appearance.colors.textDim

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -6
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.notif.dismiss()
                    }
                }
            }

            StyledText {
                width: parent.width
                text: root.notif.summary
                font.bold: true
                wrapMode: Text.Wrap
                maximumLineCount: 2
            }

            StyledText {
                width: parent.width
                visible: text !== ""
                text: root.notif.body
                textFormat: Text.StyledText
                color: Appearance.colors.textDim
                wrapMode: Text.Wrap
                maximumLineCount: root.popup ? 4 : 3
                onLinkActivated: link => Qt.openUrlExternally(link)
            }

            Row {
                spacing: 6
                visible: actionsRepeater.count > 0
                topPadding: 4

                Repeater {
                    id: actionsRepeater
                    model: root.notif.actions.filter(a => a.identifier !== "default" && a.text !== "")

                    Rectangle {
                        id: action
                        required property NotificationAction modelData

                        width: label.implicitWidth + 24
                        height: 30
                        radius: height / 2
                        color: Appearance.colors.primaryContainer

                        StyledText {
                            id: label
                            anchors.centerIn: parent
                            text: action.modelData.text
                            font.pointSize: Appearance.font.small
                        }

                        StateLayer {
                            onClicked: action.modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
