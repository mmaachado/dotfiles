pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Every colour comes from the active KDE colour scheme / accent colour, so the
// shell follows System Settings → Colors & Themes (including accent-from-wallpaper).
Singleton {
    id: root

    // KDE's animation speed (System Settings → General Behavior). 0 = no animations.
    property real motion: 1

    FileView {
        path: Quickshell.env("HOME") + "/.config/kdeglobals"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/^AnimationDurationFactor=([\d.]+)/m);
            root.motion = m ? parseFloat(m[1]) : 1;
        }
        onLoadFailed: root.motion = 1
    }

    // Active KShell theme (written by bridge/themes.py). Blur themes make the
    // shell translucent and ask KWin to blur behind it.
    property bool blur: false

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/kshell/theme.json"
        printErrors: false // absent until the first theme is applied
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.blur = JSON.parse(text()).blur === true;
            } catch (e) {
                root.blur = false;
            }
        }
        onLoadFailed: root.blur = false
    }

    // Blur the wallpaper and desktop while an app window has focus
    // (modules/Backdrop.qml). Skipped while a window is fullscreen.
    readonly property bool backdropBlur: true

    readonly property SystemPalette palette: SystemPalette { colorGroup: SystemPalette.Active }

    // Layer a tint over the window colour: opaque normally, a translucent
    // overlay in blur themes (so the blurred background shows through).
    function layer(over: color, amount: real): color {
        return root.blur ? Qt.alpha(over, amount) : Qt.tint(root.palette.window, Qt.alpha(over, amount));
    }

    readonly property QtObject colors: QtObject {
        readonly property color frame: root.blur ? Qt.alpha(root.palette.window, 0.62) : root.palette.window
        // Things floating over the desktop without a blurred frame behind them.
        readonly property color popup: root.blur ? Qt.alpha(root.palette.window, 0.92) : root.palette.window
        readonly property color surface: root.layer(root.palette.windowText, 0.06)
        readonly property color surfaceHigh: root.layer(root.palette.windowText, 0.11)
        readonly property color surfaceHighest: Qt.tint(root.palette.window, Qt.alpha(root.palette.windowText, 0.16))
        readonly property color primary: root.palette.highlight
        readonly property color onPrimary: root.palette.highlightedText
        readonly property color primaryContainer: root.layer(root.palette.highlight, 0.3)
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
        readonly property int fast: Math.round(150 * root.motion)
        readonly property int normal: Math.round(300 * root.motion)
        readonly property int slow: Math.round(450 * root.motion)
        // Material 3 "emphasized" curves
        readonly property var enter: [0.05, 0.7, 0.1, 1, 1, 1]
        readonly property var exit: [0.3, 0, 0.8, 0.15, 1, 1]
        readonly property var standard: [0.2, 0, 0, 1, 1, 1]
    }
}
