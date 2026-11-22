import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Settings → About: droid's version and codename (from droid.toml) and what
// it runs on.
Column {
    id: root

    spacing: 10

    Rectangle {
        width: parent.width
        implicitHeight: hero.implicitHeight + 56
        radius: Appearance.sizes.radius
        color: Appearance.colors.primaryContainer

        Column {
            id: hero
            anchors.centerIn: parent
            width: parent.width - 48
            spacing: 4

            // This major version's art (assets/droid_<codename>.svg).
            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: status === Image.Ready
                source: Release.art ? "file://" + Release.art : ""
                sourceSize.height: 140
                fillMode: Image.PreserveAspectFit
                asynchronous: true
            }

            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Release.name
                font.pointSize: Appearance.font.huge
                font.bold: true
                color: Appearance.colors.text
            }
            StyledText {
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: Release.version ? `Version ${Release.version} · ${Release.codename}` : "Version unknown"
                font.pointSize: Appearance.font.large
                color: Appearance.colors.text
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                horizontalAlignment: Text.AlignHCenter
                text: Release.description
                color: Appearance.colors.text
                opacity: 0.8
            }
        }
    }

    Heading {
        text: "Runs on"
    }

    SettingRow {
        icon: "plasma"
        label: "KDE Plasma"
        description: "Window manager (KWin), session, settings, power and devices"
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Release.plasma || "?"
            color: Appearance.colors.textDim
        }
    }

    SettingRow {
        icon: "code-context"
        label: "Quickshell"
        description: "Draws KShell: the bar, notch, drawers and this window"
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Release.quickshell || "?"
            color: Appearance.colors.textDim
        }
    }

    Heading {
        text: "Links"
    }

    Flow {
        width: parent.width
        spacing: 8

        PillButton {
            label: "droid on GitHub"
            primary: true
            onClicked: Qt.openUrlExternally(Release.repo)
        }
        PillButton {
            label: "Report a bug"
            onClicked: Qt.openUrlExternally(Release.repo + "/issues/new/choose")
        }
        PillButton {
            label: "droid-icons"
            onClicked: Qt.openUrlExternally("https://github.com/mmaachado/droid-icons")
        }
    }
}
