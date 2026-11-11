//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// KShell — a Caelestia-style shell running on top of KDE Plasma.
// Plasma (plasmashell) keeps the wallpaper and desktop widgets; KWin keeps
// window management. This replaces the Plasma panels.
import QtQuick
import Quickshell
import qs.config
import qs.modules
import qs.modules.settings
import qs.services

ShellRoot {
    // Singletons load on first use; this one has to run from the start to
    // keep the Material colours in step with the wallpaper and theme.
    readonly property bool materialColours: Scheme.active

    LazyLoader {
        active: Settings.open

        SettingsWindow {
            visible: true
        }
    }

    Variants {
        model: Quickshell.screens

        ScreenShell {}
    }
}
