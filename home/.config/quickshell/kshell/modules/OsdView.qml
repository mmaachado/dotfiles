import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The OSD's content: a vertical gauge for levels (volume, ...), one gauge
// per monitor for brightness,
// or an icon and a line of text. Lives in a drawer on the right edge.
Item {
    id: root

    readonly property bool progress: Osd.kind === "progress"
    readonly property bool brightness: Osd.kind === "brightness"
    readonly property int trackHeight: 180

    implicitWidth: progress ? 44 : brightness ? screens.implicitWidth : textRow.implicitWidth
    implicitHeight: progress ? col.implicitHeight : brightness ? screens.implicitHeight : textRow.implicitHeight

    // A vertical gauge: the number on top, the filled track with an icon.
    component Gauge: Column {
        id: gauge
        property real value
        property string icon
        property string label

        width: Math.max(44, labelText.implicitWidth)
        spacing: 10

        Spring {
            id: gaugeLevel
            target: gauge.value
            preset: Appearance.spring.fastSpatial
            epsilon: 0.002
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Math.round(gauge.value * 100)
            font.bold: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 44
            height: root.trackHeight
            radius: width / 2
            color: Appearance.colors.secondaryContainer

            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width
                height: Math.max(width, parent.height * Math.min(1.08, Math.max(0, gaugeLevel.value)))
                radius: width / 2
                color: Appearance.colors.primary
            }

            Icon {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 12
                name: gauge.icon
                size: 20
                color: Appearance.colors.onPrimary
            }
        }

        StyledText {
            id: labelText
            anchors.horizontalCenter: parent.horizontalCenter
            visible: gauge.label !== ""
            text: gauge.label
            color: Appearance.colors.textDim
            font.pointSize: Appearance.font.small
        }
    }

    // Brightness: a gauge per monitor, side by side.
    Row {
        id: screens
        visible: root.brightness
        spacing: 14

        Repeater {
            model: ScriptModel {
                values: Brightness.displays.map(d => d.name)
            }

            Gauge {
                required property string modelData
                readonly property var display: Brightness.displays.find(d => d.name === modelData) ?? null
                value: display?.value ?? 0
                icon: Brightness.iconFor(value)
                label: Brightness.displays.length > 1 && display ? Brightness.shortLabel(display) : ""
            }
        }
    }

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
        visible: Osd.kind === "text"
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
