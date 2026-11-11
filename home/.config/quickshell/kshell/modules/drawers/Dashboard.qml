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

// Dashboard: clock, calendar & resources | media | quick settings | notifications
Row {
    id: root

    property bool open
    readonly property int sectionHeight: quick.hasBattery ? 476 : 416

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
                height: 160
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

        // Resources
        Row {
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 16

            Ring { width: 50; value: SysStats.cpu; text: `${Math.round(SysStats.cpu * 100)}`; caption: "CPU" }
            Ring { width: 50; value: SysStats.mem; text: `${Math.round(SysStats.mem * 100)}`; caption: "RAM" }
            Ring { width: 50; value: SysStats.disk; text: `${Math.round(SysStats.disk * 100)}`; caption: "Disk" }
            Ring {
                width: 50
                visible: SysStats.temp > 0
                value: SysStats.temp / 100
                text: `${Math.round(SysStats.temp)}°`
                caption: "Temp"
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

            // Seek bar: the wave drifts while playing.
            WavySlider {
                width: parent.width
                height: 24
                visible: (media.player?.lengthSupported ?? false) && media.player.length > 0
                enabled: media.player?.canSeek ?? false
                flowing: media.player?.isPlaying ?? false
                wavy: media.player?.isPlaying ?? false
                amplitude: 2.6
                value: (media.player?.position ?? 0) / Math.max(1, media.player?.length ?? 1)
                onMoved: v => media.player.position = media.player.length * v
            }

            // MPRIS doesn't push position updates; ask while it's on screen.
            Timer {
                running: root.open && (media.player?.isPlaying ?? false)
                interval: 1000
                repeat: true
                onTriggered: media.player.positionChanged()
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

    // ── Quick settings ───────────────────────────────────────────────
    Section {
        width: 364
        clip: true

        QuickSettings {
            id: quick
            anchors.fill: parent
            open: root.open
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
