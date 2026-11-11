pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Colours come from one of two places (Settings → Appearance → Colours):
// - the active KDE colour scheme / accent colour, so the shell follows System
//   Settings → Colors & Themes (including accent-from-wallpaper), or
// - a Material 3 scheme built by kshelld from the wallpaper or the theme's
//   accent (services/Scheme.qml writes it; this reads it).
// Role names (surface, primaryContainer, …) are the same either way.
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

    // Active KShell theme (written by kshelld theme). Blur themes make the
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
    readonly property bool backdropBlur: Settings.options.backdropBlur

    readonly property SystemPalette palette: SystemPalette { colorGroup: SystemPalette.Active }

    // The Material 3 scheme (role → "#rrggbb"), if one is in use.
    property var m3: ({})
    readonly property bool material: Settings.options.colorSource !== "kde" && m3.primary !== undefined

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/kshell/scheme.json"
        printErrors: false // absent until the first scheme is built
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.m3 = JSON.parse(text()).colors;
            } catch (e) {}
        }
    }

    // Shell colours: the Material scheme's; else the KDE scheme's, unless
    // overridden in Settings. With a custom background, text flips to black
    // or white to stay readable.
    readonly property color base: material ? m3.surface : Settings.options.baseColor || palette.window
    readonly property color accent: material ? m3.primary : Settings.options.accentColor || palette.highlight
    readonly property color ink: material ? m3.onSurface
        : Settings.options.baseColor ? contrast(base) : palette.windowText
    readonly property real frameOpacity: Settings.options.frameOpacity

    function luma(c: color): real {
        return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b;
    }

    function contrast(c: color): color {
        return luma(c) > 0.55 ? "#1e1e1e" : "#f2f2f2";
    }

    // Layer a tint over the window colour: opaque normally, a translucent
    // overlay in blur themes (so the blurred background shows through).
    function layer(over: color, amount: real): color {
        return root.blur ? Qt.alpha(over, amount) : Qt.tint(root.base, Qt.alpha(over, amount));
    }

    // Picks the Material role when there is one, else the KDE-derived colour.
    // Blur themes keep their translucent layering either way.
    function role(name: string, fallback: color): color {
        return material && !blur ? m3[name] : fallback;
    }

    // Colour changes (a new wallpaper or theme) blend instead of snapping.
    readonly property int blend: Math.round(900 * motion)

    // The blended colours live on the singleton itself: Quickshell crashes on
    // a Behavior inside the nested `colors` object.
    property color c_frame: root.blur ? Qt.alpha(root.base, root.frameOpacity) : root.base
    Behavior on c_frame { ColorAnimation { duration: root.blend } }
    // Things floating over the desktop without a blurred frame behind them.
    property color c_popup: root.blur ? Qt.alpha(root.base, Math.min(1, root.frameOpacity + 0.3)) : root.base
    Behavior on c_popup { ColorAnimation { duration: root.blend } }
    property color c_surfaceLow: root.role("surfaceContainerLow", root.layer(root.ink, 0.03))
    Behavior on c_surfaceLow { ColorAnimation { duration: root.blend } }
    property color c_surface: root.role("surfaceContainer", root.layer(root.ink, 0.06))
    Behavior on c_surface { ColorAnimation { duration: root.blend } }
    property color c_surfaceHigh: root.role("surfaceContainerHigh", root.layer(root.ink, 0.11))
    Behavior on c_surfaceHigh { ColorAnimation { duration: root.blend } }
    property color c_surfaceHighest: root.role("surfaceContainerHighest", Qt.tint(root.base, Qt.alpha(root.ink, 0.16)))
    Behavior on c_surfaceHighest { ColorAnimation { duration: root.blend } }
    property color c_primary: root.accent
    Behavior on c_primary { ColorAnimation { duration: root.blend } }
    property color c_onPrimary: root.material ? root.m3.onPrimary
        : Settings.options.accentColor ? root.contrast(root.accent) : root.palette.highlightedText
    Behavior on c_onPrimary { ColorAnimation { duration: root.blend } }
    property color c_primaryContainer: root.role("primaryContainer", root.layer(root.accent, 0.3))
    Behavior on c_primaryContainer { ColorAnimation { duration: root.blend } }
    property color c_onPrimaryContainer: root.role("onPrimaryContainer", root.ink)
    Behavior on c_onPrimaryContainer { ColorAnimation { duration: root.blend } }
    property color c_secondary: root.material ? root.m3.secondary : Qt.alpha(root.accent, 0.8)
    Behavior on c_secondary { ColorAnimation { duration: root.blend } }
    property color c_secondaryContainer: root.role("secondaryContainer", root.layer(root.accent, 0.18))
    Behavior on c_secondaryContainer { ColorAnimation { duration: root.blend } }
    property color c_onSecondaryContainer: root.role("onSecondaryContainer", root.ink)
    Behavior on c_onSecondaryContainer { ColorAnimation { duration: root.blend } }
    property color c_tertiary: root.material ? root.m3.tertiary : root.accent
    Behavior on c_tertiary { ColorAnimation { duration: root.blend } }
    property color c_tertiaryContainer: root.role("tertiaryContainer", root.layer(root.accent, 0.22))
    Behavior on c_tertiaryContainer { ColorAnimation { duration: root.blend } }
    property color c_onTertiaryContainer: root.role("onTertiaryContainer", root.ink)
    Behavior on c_onTertiaryContainer { ColorAnimation { duration: root.blend } }
    property color c_text: root.ink
    Behavior on c_text { ColorAnimation { duration: root.blend } }
    property color c_textDim: root.material ? root.m3.onSurfaceVariant : Qt.alpha(root.ink, 0.65)
    Behavior on c_textDim { ColorAnimation { duration: root.blend } }
    property color c_textFaint: Qt.alpha(root.c_textDim, root.material ? 0.6 : 0.54)
    Behavior on c_textFaint { ColorAnimation { duration: root.blend } }
    property color c_outline: root.role("outlineVariant", Qt.alpha(root.ink, 0.12))
    Behavior on c_outline { ColorAnimation { duration: root.blend } }
    property color c_error: root.material ? root.m3.error : "#da4453"
    Behavior on c_error { ColorAnimation { duration: root.blend } }

    readonly property QtObject colors: QtObject {
        readonly property color frame: root.c_frame
        readonly property color popup: root.c_popup
        readonly property color surfaceLow: root.c_surfaceLow
        readonly property color surface: root.c_surface
        readonly property color surfaceHigh: root.c_surfaceHigh
        readonly property color surfaceHighest: root.c_surfaceHighest
        readonly property color primary: root.c_primary
        readonly property color onPrimary: root.c_onPrimary
        readonly property color primaryContainer: root.c_primaryContainer
        readonly property color onPrimaryContainer: root.c_onPrimaryContainer
        readonly property color secondary: root.c_secondary
        readonly property color secondaryContainer: root.c_secondaryContainer
        readonly property color onSecondaryContainer: root.c_onSecondaryContainer
        readonly property color tertiary: root.c_tertiary
        readonly property color tertiaryContainer: root.c_tertiaryContainer
        readonly property color onTertiaryContainer: root.c_onTertiaryContainer
        readonly property color text: root.c_text
        readonly property color textDim: root.c_textDim
        readonly property color textFaint: root.c_textFaint
        readonly property color outline: root.c_outline
        readonly property color error: root.c_error
    }

    readonly property QtObject sizes: QtObject {
        readonly property int barWidth: 52
        readonly property int border: 10
        // Collapsed notch (it flattens into the top border when windows get close).
        readonly property int notchHeight: 36
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

    // Material 3 Expressive springs, [stiffness, damping ratio] (as in
    // androidx.compose.material3 MotionScheme / md3e). Spatial ones move
    // things and may bounce; effects ones fade or recolour and never do.
    // Used by components/Spring.qml.
    readonly property QtObject spring: QtObject {
        readonly property var fastSpatial: [800, 0.6]
        readonly property var defaultSpatial: [380, 0.8]
        readonly property var slowSpatial: [200, 0.8]
        readonly property var fastEffects: [3800, 1]
        readonly property var defaultEffects: [1600, 1]
        readonly property var slowEffects: [800, 1]
        // Leaving / collapsing: quick and without bounce, so nothing
        // undershoots past closed.
        readonly property var exit: [800, 1]
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
