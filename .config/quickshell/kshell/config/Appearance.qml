pragma Singleton

import QtQuick
import Quickshell

// Every colour comes from the active KDE colour scheme / accent colour, so the
// shell follows System Settings → Colors & Themes (including accent-from-wallpaper).
Singleton {
    id: root

    readonly property SystemPalette palette: SystemPalette { colorGroup: SystemPalette.Active }

    readonly property QtObject colors: QtObject {
        readonly property color frame: root.palette.window
        readonly property color surface: Qt.tint(root.palette.window, Qt.alpha(root.palette.windowText, 0.05))
        readonly property color surfaceHigh: Qt.tint(root.palette.window, Qt.alpha(root.palette.windowText, 0.10))
        readonly property color surfaceHighest: Qt.tint(root.palette.window, Qt.alpha(root.palette.windowText, 0.16))
        readonly property color primary: root.palette.highlight
        readonly property color onPrimary: root.palette.highlightedText
        readonly property color primaryContainer: Qt.tint(root.palette.window, Qt.alpha(root.palette.highlight, 0.28))
        readonly property color text: root.palette.windowText
        readonly property color textDim: Qt.alpha(root.palette.windowText, 0.65)
        readonly property color textFaint: Qt.alpha(root.palette.windowText, 0.35)
        readonly property color outline: Qt.alpha(root.palette.windowText, 0.12)
        readonly property color error: "#da4453"
    }

    readonly property QtObject sizes: QtObject {
        readonly property int barWidth: 52
        readonly property int border: 10
        readonly property int rounding: 24
        readonly property int radius: 16
        readonly property int radiusSmall: 10
        readonly property int padding: 16
        readonly property int spacing: 10
        readonly property int iconBar: 22
        readonly property int iconTray: 18
    }

    readonly property QtObject font: QtObject {
        readonly property string family: Qt.application.font.family
        readonly property string mono: "JetBrains Mono"
        readonly property real small: 9
        readonly property real normal: 10.5
        readonly property real large: 13
        readonly property real xl: 18
        readonly property real huge: 40
    }

    readonly property QtObject anim: QtObject {
        readonly property int fast: 150
        readonly property int normal: 300
        readonly property int slow: 450
        // Material 3 "emphasized" curves
        readonly property var enter: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var exit: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    }
}
