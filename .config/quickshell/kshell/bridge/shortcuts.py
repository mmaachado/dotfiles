#!/usr/bin/env python3
"""Move the bare Meta key between Plasma's launcher action and KShell's.

    shortcuts.py kshell   Meta → KShell launcher (Plasma keeps Alt+F1)
    shortcuts.py plasma   Meta → Plasma's application launcher again
"""
import sys

from gi.repository import Gio, GLib

META = 0x01000022           # Qt::Key_Meta (modifier-only shortcut)
META_SPACE = 0x10000020     # Qt::META | Qt::Key_Space
ALT_F1 = 0x08000000 | 0x01000030

PLASMA = ["plasmashell", "activate application launcher", "", ""]
KSHELL = ["kwin", "KShell Launcher", "", ""]

bus = Gio.bus_get_sync(Gio.BusType.SESSION)


def set_keys(action, keys):
    seqs = [([k, 0, 0, 0],) for k in keys]
    bus.call_sync("org.kde.kglobalaccel", "/kglobalaccel", "org.kde.KGlobalAccel",
                  "setForeignShortcutKeys", GLib.Variant("(asa(ai))", (action, seqs)),
                  None, Gio.DBusCallFlags.NONE, -1, None)


if sys.argv[1:] == ["kshell"]:
    set_keys(PLASMA, [ALT_F1])
    set_keys(KSHELL, [META, META_SPACE])
elif sys.argv[1:] == ["plasma"]:
    set_keys(KSHELL, [META_SPACE])
    set_keys(PLASMA, [META, ALT_F1])
else:
    sys.exit(__doc__)
