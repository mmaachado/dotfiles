import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The capture toolbar (Meta+Shift+5), like macOS's: capture the whole
// desktop, this display, a window or a region, or record the screen or a
// region; below, the timer, pointer and save-folder options.
Column {
    id: root

    property bool open

    spacing: 12

    onOpenChanged: {
        if (open)
            forceActiveFocus();
        else
            focus = false; // see Launcher.qml
    }
    Keys.onEscapePressed: Visibilities.closeAll()

    function run(action: var): void {
        Visibilities.closeAll();
        action();
    }

    // A tool: icon over a label.
    component Tool: Rectangle {
        id: tool
        property string icon
        property string label
        property bool danger
        signal activated

        width: 92
        height: 72
        radius: Appearance.sizes.radius
        color: layer.containsMouse ? Appearance.colors.surfaceHigh : "transparent"

        Column {
            anchors.centerIn: parent
            spacing: 6
            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                name: tool.icon
                size: 26
                color: tool.danger ? Appearance.colors.error : Appearance.colors.text
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: tool.label
                font.pointSize: Appearance.font.small
                color: Appearance.colors.textDim
            }
        }
        StateLayer {
            id: layer
            onClicked: tool.activated()
        }
    }

    component Divider: Rectangle {
        width: 1
        height: 48
        anchors.verticalCenter: parent?.verticalCenter
        color: Appearance.colors.outline
        opacity: 0.4
    }

    component Chip: Rectangle {
        id: chip
        property string label
        property bool on
        signal clicked

        width: chipText.implicitWidth + 24
        height: 30
        radius: height / 2
        color: on ? Appearance.colors.primary : Appearance.colors.surfaceHigh

        StyledText {
            id: chipText
            anchors.centerIn: parent
            text: chip.label
            font.pointSize: Appearance.font.small
            color: chip.on ? Appearance.colors.onPrimary : Appearance.colors.text
        }
        StateLayer {
            tint: chip.on ? Appearance.colors.onPrimary : Appearance.colors.text
            onClicked: chip.clicked()
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 4

        Tool {
            icon: "view-fullscreen-symbolic"
            label: "Everything"
            onActivated: root.run(() => Capture.shot("full"))
        }
        Tool {
            icon: "video-display-symbolic"
            label: "This display"
            onActivated: root.run(() => Capture.shot("screen"))
        }
        Tool {
            icon: "window-symbolic"
            label: "Window"
            onActivated: root.run(() => Capture.shot("window"))
        }
        Tool {
            icon: "select-rectangular-symbolic"
            label: "Region"
            onActivated: root.run(() => Capture.shot("region"))
        }

        Divider {}

        Tool {
            icon: "media-record-symbolic"
            label: "Record display"
            danger: true
            onActivated: root.run(() => Capture.record("screen"))
        }
        Tool {
            icon: "media-record-symbolic"
            label: "Record region"
            danger: true
            onActivated: root.run(() => Capture.record("region"))
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 8

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: "Timer"
            color: Appearance.colors.textDim
            font.pointSize: Appearance.font.small
        }
        Repeater {
            model: [[0, "Off"], [5, "5 s"], [10, "10 s"]]
            Chip {
                required property var modelData
                label: modelData[1]
                on: Settings.options.screenshotDelay === modelData[0]
                onClicked: Settings.options.screenshotDelay = modelData[0]
            }
        }

        Item { width: 12; height: 1 }

        Chip {
            label: "Show pointer"
            on: Settings.options.screenshotPointer
            onClicked: Settings.options.screenshotPointer = !on
        }

        Item { width: 12; height: 1 }

        Chip {
            label: "Open folder"
            onClicked: {
                Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", Capture.dir]);
                Visibilities.closeAll();
            }
        }
    }

    StyledText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: `Saved to ${Capture.dir.replace(Quickshell.env("HOME"), "~")} and copied   ·   Meta+Shift+3 everything, Print or Meta+Shift+4 region`
        color: Appearance.colors.textFaint
        font.pointSize: Appearance.font.small
    }
}
