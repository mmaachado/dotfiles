import QtQuick
import qs.components
import qs.config
import qs.services

// Shown while a screen recording runs: a red pill with the elapsed time.
// Click to stop and save the recording.
Rectangle {
    id: root

    readonly property bool vertical: Appearance.barVertical
    property int seconds: 0

    visible: Capture.recording
    implicitWidth: vertical ? Appearance.sizes.barWidth - 12 : content.implicitWidth + 20
    implicitHeight: vertical ? content.implicitHeight + 16 : Appearance.sizes.barWidth - 12
    radius: Math.min(width, height) / 2
    color: Appearance.colors.error

    onVisibleChanged: seconds = 0

    Timer {
        running: Capture.recording
        interval: 1000
        repeat: true
        onTriggered: root.seconds++
    }

    Grid {
        id: content
        anchors.centerIn: parent
        columns: root.vertical ? 1 : 2
        spacing: 6
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        Icon {
            name: "media-playback-stop-symbolic"
            size: 16
            color: "white"
        }
        StyledText {
            text: `${Math.floor(root.seconds / 60)}:${String(root.seconds % 60).padStart(2, "0")}`
            font.pointSize: Appearance.font.small
            font.bold: true
            color: "white"
        }
    }

    StateLayer {
        tint: "white"
        onClicked: Capture.stop()
    }

    Tooltip {
        text: "Stop recording"
        shown: tip.shown
    }
    HoverDelay {
        id: tip
        hovered: hoverHandler.hovered
    }
    HoverHandler {
        id: hoverHandler
    }
}
