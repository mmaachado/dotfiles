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

ShellRoot {
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
