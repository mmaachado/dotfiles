#!/usr/bin/env python3
"""Swap global shortcuts between Plasma's defaults and KShell's.

    shortcuts.py kshell   Meta → KShell launcher (Plasma keeps Alt+F1),
                          Meta+W → wallpaper picker, KWin Overview → Meta+O
    shortcuts.py plasma   restore Plasma's Meta and Meta+W bindings
"""
import sys

from gi.repository import Gio, GLib

META = 0x01000022           # Qt::Key_Meta (modifier-only shortcut)
META_SPACE = 0x10000020     # Qt::META | Qt::Key_Space
ALT_F1 = 0x08000000 | 0x01000030
META_W = 0x10000000 | 0x57
META_O = 0x10000000 | 0x4F

PLASMA = ["plasmashell", "activate application launcher", "", ""]
KSHELL = ["kwin", "KShell Launcher", "", ""]
OVERVIEW = ["kwin", "Overview", "", ""]
WALLPAPERS = ["kwin", "KShell Wallpapers", "", ""]

bus = Gio.bus_get_sync(Gio.BusType.SESSION)


def set_keys(action, keys):
    seqs = [([k, 0, 0, 0],) for k in keys]
    bus.call_sync("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
                  "setForeignShortcutKeys", GLib.Variant("(asa(ai))", (action, seqs)),
                  None, Gio.DBusCallFlags.NONE, -1, None)


if sys.argv[1:] == ["kshell"]:
    set_keys(PLASMA, [ALT_F1])
    set_keys(KSHELL, [META, META_SPACE])
    set_keys(OVERVIEW, [META_O])         # free Meta+W first
    set_keys(WALLPAPERS, [META_W])
elif sys.argv[1:] == ["plasma"]:
    set_keys(KSHELL, [META_SPACE])
    set_keys(PLASMA, [META, ALT_F1])
    set_keys(WALLPAPERS, [])
    set_keys(OVERVIEW, [META_W])
else:
    sys.exit(__doc__)
