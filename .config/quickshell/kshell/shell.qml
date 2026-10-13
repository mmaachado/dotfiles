//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

// KShell — a Caelestia-style shell running on top of KDE Plasma.
// Plasma (plasmashell) keeps the wallpaper and desktop widgets; KWin keeps
// window management. This replaces the Plasma panels.
import QtQuick
import Quickshell
import qs.modules

ShellRoot {
    Variants {
        model: Quickshell.screens

        ScreenShell {}
    }
}
