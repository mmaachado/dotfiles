pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// User settings, edited in the settings window (modules/settings) and saved to
// config/settings.json. Hand edits to the file apply live too.
Singleton {
    id: root

    property bool open: false
    // Page shown in the settings window; kept while it's closed.
    property int page: 0
    readonly property alias options: adapter

    function toggle(): void {
        root.open = !root.open;
    }

    FileView {
        path: Quickshell.shellDir + "/config/settings.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        // First run: write the defaults out.
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            // Blur the wallpaper and desktop while an app has focus (Backdrop.qml).
            property bool backdropBlur: true
            // SystemTrayItem ids left out of the bar's tray.
            property list<string> hiddenTray: []
            // Empty = ~/Pictures/Wallpapers.
            property string wallpaperDir: ""
            property bool wallpaperTransition: true
            // same (every display) | per-display (the one the picker opened on).
            property string wallpaperMode: "same"
            // How each display's wallpaper fills it, by screen name: crop |
            // fit | stretch | center | tile. Missing = crop (Plasma's default).
            property var wallpaperFill: ({})
            // Fit and center: blur the wallpaper into the empty space (else black).
            property bool wallpaperBlur: true
            // Length of the wallpaper transition, in ms (scaled by KDE's animation speed).
            property int transitionDuration: 2600
            // liquid | fade | wipe | circle | pixelate | dissolve | random
            property string transitionEffect: "liquid"

            // Where colours come from: kde (the KDE colour scheme, plus the
            // overrides below) | wallpaper (Material 3 from the wallpaper) |
            // theme (Material 3 from the active theme's accent).
            property string colorSource: "kde"
            // Material 3 scheme variant: tonal-spot | expressive | vibrant |
            // fidelity | content | rainbow | fruit-salad | neutral | monochrome
            property string schemeVariant: "tonal-spot"
            // Recolour Plasma, Qt/GTK apps and kitty with the Material scheme too.
            property bool schemeApps: true

            // Shell colours when colorSource is kde. "" = follow the KDE colour scheme.
            property string accentColor: ""
            property string baseColor: ""
            // How opaque the shell is in blur themes.
            property real frameOpacity: 0.62

            // Status icons in the bar: ethernet, wifi, bluetooth, sound, battery, power.
            property list<string> statusIcons: ["ethernet", "sound"]

            // Which screen edge the bar sits on: left | top | right | bottom.
            property string barPosition: "left"
            // Show KWin's virtual desktops in the bar.
            property bool barDesktops: true

            // Multiple displays: where the bar and the notch show (all |
            // primary), and where notification popups appear (primary | active).
            property string barDisplays: "all"
            property string notchDisplays: "all"
            property string popupDisplays: "primary"

            // System icons (droid-icons): rounded | outlined | sharp, filled or not.
            property string iconStyle: "rounded"
            property bool iconFilled: true

            // Screenshots (services/Capture.qml): "" = ~/Pictures/Screenshots;
            // timer in seconds; include the pointer.
            property string screenshotDir: ""
            property int screenshotDelay: 0
            property bool screenshotPointer: false

            // Keep the clipboard in sync with phones paired in KDE Connect.
            property bool clipboardPhoneSync: true

            // AI plan usage beside the tray (ai-usagebar, when installed).
            property bool aiUsage: true

            // Draw KShell's own OSD (volume, brightness, ...) instead of Plasma's.
            property bool osd: true

            // Collapsed notch: time | date | datetime, plus what else it shows.
            property string notchClock: "time"
            property bool notchMedia: true
            property bool notchNotifications: true
        }
    }
}
