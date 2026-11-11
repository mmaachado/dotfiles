import QtQuick
import qs.components
import qs.config
import qs.services

// The OSD's content: a vertical gauge for levels (volume, brightness, ...),
// or an icon and a line of text. Lives in a drawer on the right edge.
Item {
    id: root

    readonly property bool progress: Osd.kind === "progress"
    readonly property int trackHeight: 180

    implicitWidth: progress ? 44 : textRow.implicitWidth
    implicitHeight: progress ? col.implicitHeight : textRow.implicitHeight

    Spring {
        id: level
        target: Osd.value
        preset: Appearance.spring.fastSpatial
        epsilon: 0.002
    }

    Column {
        id: col
        visible: root.progress
        width: 44
        spacing: 10

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(Osd.value * 100)
            font.bold: true
        }

        Rectangle {
            width: parent.width
            height: root.trackHeight
            radius: width / 2
            color: Appearance.colors.secondaryContainer

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(width, parent.height * Math.min(1.08, Math.max(0, level.value)))
                radius: width / 2
                color: Appearance.colors.primary
            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                name: Osd.icon ? Osd.icon + "-symbolic" : ""
                fallback: Osd.icon
                size: 20
                color: Appearance.colors.onPrimary
            }
        }
    }

    Row {
        id: textRow
        visible: !root.progress
        spacing: 12
        height: 32

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: Osd.icon ? Osd.icon + "-symbolic" : ""
            fallback: Osd.icon
            size: 22
            color: Appearance.colors.text
        }
        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: Osd.text
            font.bold: true
            font.pointSize: Appearance.font.large
        }
    }
}
