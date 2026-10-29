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
            // Length of the wallpaper transition, in ms (scaled by KDE's animation speed).
            property int transitionDuration: 2600
            // liquid | fade | wipe | circle | pixelate | dissolve | random
            property string transitionEffect: "liquid"

            // Shell colours. "" = follow the KDE colour scheme.
            property string accentColor: ""
            property string baseColor: ""
            // How opaque the shell is in blur themes.
            property real frameOpacity: 0.62

            // Status icons in the bar: ethernet, wifi, bluetooth, sound, battery, power.
            property list<string> statusIcons: ["ethernet", "sound"]

            // Collapsed notch: time | date | datetime, plus what else it shows.
            property string notchClock: "time"
            property bool notchMedia: true
            property bool notchNotifications: true
        }
    }
}
