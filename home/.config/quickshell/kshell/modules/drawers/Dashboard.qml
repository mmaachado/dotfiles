import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services
import qs.modules.notifications

// Dashboard: clock + calendar | media | controls & resources | notifications
Row {
    id: root

    property bool open
    readonly property int sectionHeight: 380

    spacing: 14

    Component.onCompleted: SysStats.users++
    Component.onDestruction: SysStats.users--

    component Section: Rectangle {
        default property alias content: inner.data
        property int pad: 16

        height: root.sectionHeight
        radius: Appearance.sizes.radius
        color: Appearance.colors.surface

        Item {
            id: inner
            anchors.fill: parent
            anchors.margins: parent.pad
        }
    }

    component Meter: Column {
        property string label
        property real value
        property string detail

        width: parent.width
        spacing: 6

        Item {
            width: parent.width
            height: l.implicitHeight
            StyledText { id: l; text: label; color: Appearance.colors.textDim; font.pointSize: Appearance.font.small }
            StyledText { anchors.right: parent.right; text: detail || `${Math.round(value * 100)}%`; font.pointSize: Appearance.font.small }
        }
        Rectangle {
            width: parent.width
            height: 8
            radius: 4
            color: Appearance.colors.surfaceHigh
            Rectangle {
                width: parent.width * Math.min(1, value)
                height: parent.height
                radius: 4
                color: value > 0.85 ? Appearance.colors.error : Appearance.colors.primary
                Behavior on width { NumberAnimation { duration: Appearance.anim.normal } }
            }
        }
    }

    component Toggle: Rectangle {
        id: toggle
        property string icon
        property string label
        property bool on
        signal clicked

        width: (parent.width - 8) / 2
        height: 48
        radius: on ? Appearance.sizes.radius : height / 2
        color: on ? Appearance.colors.primary : Appearance.colors.surfaceHigh

        Behavior on radius { NumberAnimation { duration: Appearance.anim.normal } }
        Behavior on color { ColorAnimation { duration: Appearance.anim.fast } }

        Row {
            anchors.left: parent.left
            anchors.leftMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 10
            Icon { name: toggle.icon; size: 18; color: toggle.on ? Appearance.colors.onPrimary : Appearance.colors.text }
            StyledText { text: toggle.label; color: toggle.on ? Appearance.colors.onPrimary : Appearance.colors.text; width: toggle.width - 56 }
        }
        StateLayer {
            tint: toggle.on ? Appearance.colors.onPrimary : Appearance.colors.text
            onClicked: toggle.clicked()
        }
    }

    // ── Clock & calendar ─────────────────────────────────────────────
    Section {
        width: 300

        Column {
            anchors.fill: parent
            spacing: 4

            StyledText {
                text: Time.format(Time.use24h ? "hh:mm" : "h:mm AP")
                font.pointSize: Appearance.font.huge
                font.bold: true
                color: Appearance.colors.primary
            }
            StyledText {
                text: Time.format("dddd, d MMMM")
                font.pointSize: Appearance.font.large
                color: Appearance.colors.textDim
            }

            Item { width: 1; height: 8 }

            DayOfWeekRow {
                width: parent.width
                locale: grid.locale
                delegate: StyledText {
                    required property string shortName
                    text: shortName.slice(0, 2)
                    horizontalAlignment: Text.AlignHCenter
                    color: Appearance.colors.textDim
                    font.pointSize: Appearance.font.small
                }
            }

            MonthGrid {
                id: grid
                width: parent.width
                height: 190
                month: Time.now.getMonth()
                year: Time.now.getFullYear()
                locale: Qt.locale()
                spacing: 2
                delegate: Item {
                    required property var model
                    readonly property bool today: model.today

                    Rectangle {
                        anchors.centerIn: parent
                        width: 28
                        height: 28
                        radius: 14
                        color: parent.today ? Appearance.colors.primary : "transparent"
                    }
                    StyledText {
                        anchors.centerIn: parent
                        text: parent.model.day
                        font.pointSize: Appearance.font.small
                        font.bold: parent.today
                        color: parent.today ? Appearance.colors.onPrimary
                             : parent.model.month === grid.month ? Appearance.colors.text : Appearance.colors.textFaint
                    }
                }
            }
        }
    }

    // ── Media ────────────────────────────────────────────────────────
    Section {
        id: media
        width: 280
        readonly property MprisPlayer player: Players.active

        Column {
            anchors.fill: parent
            spacing: 12
            visible: media.player !== null

            Rectangle {
                width: parent.width
                height: width * 0.72
                radius: Appearance.sizes.radiusSmall
                color: Appearance.colors.surfaceHigh
                clip: true

                Image {
                    anchors.fill: parent
                    source: media.player?.trackArtUrl ?? ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize: Qt.size(400, 400)
                }
                Icon {
                    anchors.centerIn: parent
                    visible: !media.player?.trackArtUrl
                    name: "media-optical-audio-symbolic"
                    size: 64
                    color: Appearance.colors.textFaint
                }
            }

            Column {
                width: parent.width
                StyledText {
                    width: parent.width
                    text: media.player?.trackTitle || media.player?.identity || ""
                    font.bold: true
                    font.pointSize: Appearance.font.large
                    horizontalAlignment: Text.AlignHCenter
                }
                StyledText {
                    width: parent.width
                    text: media.player?.trackArtist ?? ""
                    color: Appearance.colors.textDim
                    horizontalAlignment: Text.AlignHCenter
                }
            }

            Rectangle {
                width: parent.width
                height: 4
                radius: 2
                color: Appearance.colors.surfaceHigh
                visible: (media.player?.lengthSupported ?? false) && media.player.length > 0
                Rectangle {
                    width: parent.width * Math.min(1, (media.player?.position ?? 0) / Math.max(1, media.player?.length ?? 1))
                    height: parent.height
                    radius: 2
                    color: Appearance.colors.primary
                }
                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    enabled: media.player?.canSeek ?? false
                    cursorShape: Qt.PointingHandCursor
                    onClicked: mouse => media.player.position = media.player.length * mouse.x / width
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                IconButton {
                    icon: "media-skip-backward-symbolic"
                    iconSize: 18
                    enabled: media.player?.canGoPrevious ?? false
                    onClicked: media.player.previous()
                }
                IconButton {
                    icon: media.player?.isPlaying ? "media-playback-pause-symbolic" : "media-playback-start-symbolic"
                    iconSize: 20
                    active: true
                    onClicked: media.player.togglePlaying()
                }
                IconButton {
                    icon: "media-skip-forward-symbolic"
                    iconSize: 18
                    enabled: media.player?.canGoNext ?? false
                    onClicked: media.player.next()
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 8
            visible: media.player === null
            Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "media-optical-audio-symbolic"; size: 48; color: Appearance.colors.textFaint }
            StyledText { text: "Nothing playing"; color: Appearance.colors.textDim }
        }
    }

    // ── Controls & resources ─────────────────────────────────────────
    Section {
        width: 300

        Column {
            anchors.fill: parent
            spacing: 12

            StyledSlider {
                width: parent.width
                value: Audio.muted ? 0 : Audio.volume
                icon: Audio.icon
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }

            Flow {
                width: parent.width
                spacing: 8

                Toggle {
                    icon: Network.icon
                    label: Network.type === "none" ? "Offline" : Network.name
                    on: Network.type !== "none"
                    onClicked: Network.toggleWifi()
                }
                Toggle {
                    readonly property var adapter: Bluetooth.defaultAdapter
                    icon: "network-bluetooth-symbolic"
                    label: "Bluetooth"
                    on: adapter?.enabled ?? false
                    visible: adapter !== null
                    onClicked: adapter.enabled = !adapter.enabled
                }
                Toggle {
                    icon: Visibilities.dnd ? "notifications-disabled-symbolic" : "notifications-symbolic"
                    label: "Do not disturb"
                    on: Visibilities.dnd
                    onClicked: Visibilities.dnd = !Visibilities.dnd
                }
                Toggle {
                    icon: "configure-symbolic"
                    label: "Settings"
                    onClicked: {
                        Visibilities.closeAll();
                        Quickshell.execDetached(["systemsettings"]);
                    }
                }
                Toggle {
                    icon: "system-shutdown-symbolic"
                    label: "Power"
                    onClicked: Visibilities.show("session", Visibilities.screen)
                }
            }

            Item { width: 1; height: 2 }

            Meter { label: "CPU"; value: SysStats.cpu }
            Meter { label: "Memory"; value: SysStats.mem; detail: `${SysStats.memUsedGiB.toFixed(1)} / ${SysStats.memTotalGiB.toFixed(1)} GiB` }
            Meter { label: "Disk ( / )"; value: SysStats.disk }
        }
    }

    // ── Notifications ────────────────────────────────────────────────
    Section {
        width: 400
        pad: 12

        Item {
            id: header
            width: parent.width
            height: 32

            StyledText {
                anchors.left: parent.left
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                text: Notifs.list.length ? `Notifications (${Notifs.list.length})` : "Notifications"
                font.bold: true
            }
            IconButton {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: Notifs.list.length > 0
                icon: "edit-clear-all-symbolic"
                iconSize: 16
                onClicked: Notifs.clearAll()
            }
        }

        ListView {
            anchors.top: header.bottom
            anchors.topMargin: 8
            anchors.bottom: parent.bottom
            width: parent.width
            clip: true
            spacing: 8
            model: Notifs.list.slice().reverse()
            delegate: NotifCard {
                required property var modelData
                notif: modelData
                width: ListView.view.width
            }

            Column {
                anchors.centerIn: parent
                spacing: 8
                visible: parent.count === 0
                Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "notifications-symbolic"; size: 40; color: Appearance.colors.textFaint }
                StyledText { text: "You're all caught up"; color: Appearance.colors.textDim }
            }
        }
    }
}
