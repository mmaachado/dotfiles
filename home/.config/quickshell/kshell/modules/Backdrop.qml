import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Blurs the wallpaper and desktop widgets while an app window has focus.
// A click-through surface on the Bottom layer (above the Plasma desktop, below
// windows) asks KWin to blur everything behind it. Clicking the desktop
// focuses it, which clears the blur.
//
// The surface is unmapped when it isn't needed (desktop focused, or a
// fullscreen window on this screen), so KWin skips the blur pass entirely.
Scope {
    id: root

    required property ShellScreen screen

    readonly property var active: Bridge.activeWindow
    readonly property bool fullscreenHere: Bridge.currentWindows.some(w => w.fullscreen && !w.minimized
        && (w.output === root.screen.name || Quickshell.screens.length === 1))
    readonly property bool wanted: Appearance.backdropBlur && active !== null && !active.minimized
        && (active.output === root.screen.name || Quickshell.screens.length === 1)
        && !fullscreenHere

    // Focus can pass through "nothing" for a moment when switching windows;
    // wait briefly before unmapping so the blur doesn't flicker.
    property bool shown: false
    onWantedChanged: {
        if (wanted) {
            hideTimer.stop();
            shown = true;
        } else {
            hideTimer.restart();
        }
    }
    Component.onCompleted: shown = wanted

    Timer {
        id: hideTimer
        interval: 120
        onTriggered: root.shown = root.wanted
    }

    PanelWindow {
        id: win

        visible: root.shown
        screen: root.screen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "kshell-backdrop"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        BackgroundEffect.blurRegion: Region { item: tint }

        // Slight dim so the focused window stands out from the blurred desktop.
        Rectangle {
            id: tint
            anchors.fill: parent
            color: Qt.alpha(Appearance.palette.window, root.shown ? 0.18 : 0)

            Behavior on color {
                ColorAnimation { duration: Appearance.anim.normal }
            }
        }
    }
}
