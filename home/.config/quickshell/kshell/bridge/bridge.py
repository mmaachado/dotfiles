#!/usr/bin/env python3
"""Bridge between KWin and KShell (Quickshell).

KWin on Wayland exposes no window list to third-party shells, so this helper
owns org.kshell.Bridge on the session bus and loads bridge.js into KWin, which
calls back with state. Everything is relayed to Quickshell over stdout:
    state <json>      window/desktop state
    ipc <target> <fn> shortcut pressed in KWin
Commands from Quickshell arrive on stdin:
    activate|toggle|close <window id>
    desktop <desktop id>
"""
import json
import os
import sys

from gi.repository import Gio, GLib

try:
    from gi.repository import GLibUnix
    signal_add = GLibUnix.signal_add
except ImportError:
    signal_add = GLib.unix_signal_add

NAME = "org.kshell.Bridge"
PATH = "/org/kshell/Bridge"
XML = """<node><interface name="org.kshell.Bridge">
  <method name="Update"><arg type="s" direction="in"/></method>
  <method name="Ipc"><arg type="s" direction="in"/></method>
  <method name="ToggleLauncher"/>
</interface></node>"""
HERE = os.path.dirname(os.path.abspath(__file__))
RUNTIME = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "kshell")
# Per-process plugin names: on a Quickshell reload the old and new bridge
# overlap, and a shared name lets the old one's cleanup unload the new script.
PLUGIN = f"kshell-bridge-{os.getpid()}"
ACTION_PLUGIN = f"kshell-action-{os.getpid()}"
PLUGIN_FILE = os.path.join(RUNTIME, "plugin")

ACTIONS = {
    "activate": "w.minimized = false; workspace.activeWindow = w;",
    "toggle": "if (workspace.activeWindow === w && !w.minimized) w.minimized = true;"
              " else { w.minimized = false; workspace.activeWindow = w; }",
    "close": "w.closeWindow();",
}

bus = Gio.bus_get_sync(Gio.BusType.SESSION)
loop = GLib.MainLoop()


def emit(line):
    try:
        sys.stdout.write(line + "\n")
        sys.stdout.flush()
    except BrokenPipeError:
        loop.quit()


def call(path, iface, method, sig=None, args=()):
    params = GLib.Variant(sig, args) if sig else None
    return bus.call_sync("org.kde.KWin", path, iface, method, params, None,
                         Gio.DBusCallFlags.NONE, -1, None)


def unload(plugin):
    call("/Scripting", "org.kde.kwin.Scripting", "unloadScript", "(s)", (plugin,))


def run_script(path, plugin):
    unload(plugin)
    sid = call("/Scripting", "org.kde.kwin.Scripting", "loadScript", "(ss)", (path, plugin)).unpack()[0]
    call(f"/Scripting/Script{sid}", "org.kde.kwin.Script", "run")


def action(kind, target):
    if kind == "desktop":
        call("/VirtualDesktopManager", "org.freedesktop.DBus.Properties", "Set", "(ssv)",
             ("org.kde.KWin.VirtualDesktopManager", "current", GLib.Variant("s", target)))
        return
    if kind not in ACTIONS:
        return
    src = ("for (const w of workspace.windowList()) if (w.internalId.toString() === %s) { %s break; }"
           % (json.dumps(target), ACTIONS[kind]))
    path = os.path.join(RUNTIME, "action.js")
    with open(path, "w") as f:
        f.write(src)
    run_script(path, ACTION_PLUGIN)


pending = None


def flush_state():
    global pending
    emit("state " + pending)
    pending = None
    return False


def on_method(conn, sender, path, iface, method, params, invocation):
    global pending
    if method == "Update":
        # Coalesce bursts (e.g. terminals animating their title).
        if pending is None:
            GLib.timeout_add(60, flush_state)
        pending = params.unpack()[0]
    elif method == "Ipc":
        emit("ipc " + params.unpack()[0])
    elif method == "ToggleLauncher":
        emit("ipc launcher toggle")
    invocation.return_value(None)


def on_stdin(source, condition):
    if condition & (GLib.IO_HUP | GLib.IO_ERR):
        loop.quit()
        return False
    line = sys.stdin.readline()
    if not line:
        loop.quit()
        return False
    parts = line.strip().split(" ", 1)
    if len(parts) == 2:
        try:
            action(*parts)
        except GLib.Error as e:
            print(f"kshell-bridge: {e.message}", file=sys.stderr)
    return True


def cleanup_stale():
    """Unload the script of a previous bridge that died without cleaning up."""
    try:
        old = open(PLUGIN_FILE).read().strip()
    except OSError:
        return
    pid = old.rsplit("-", 1)[-1]
    if old and not os.path.exists(f"/proc/{pid}"):
        for name in (old, old.replace("bridge", "action")):
            try:
                unload(name)
            except GLib.Error:
                pass


def start_script():
    cleanup_stale()
    run_script(os.path.join(HERE, "bridge.js"), PLUGIN)
    with open(PLUGIN_FILE, "w") as f:
        f.write(PLUGIN)


def main():
    os.makedirs(RUNTIME, exist_ok=True)
    node = Gio.DBusNodeInfo.new_for_xml(XML)
    bus.register_object(PATH, node.interfaces[0], on_method, None, None)
    flags = Gio.BusNameOwnerFlags.REPLACE | Gio.BusNameOwnerFlags.ALLOW_REPLACEMENT
    Gio.bus_own_name_on_connection(bus, NAME, flags,
                                   lambda *_: start_script(),
                                   lambda *_: loop.quit())
    for sig in (15, 2, 1):  # SIGTERM, SIGINT, SIGHUP
        signal_add(GLib.PRIORITY_DEFAULT, sig, lambda: loop.quit() or False)
    GLib.io_add_watch(sys.stdin.fileno(), GLib.IO_IN | GLib.IO_HUP | GLib.IO_ERR, on_stdin)
    try:
        loop.run()
    finally:
        for p in (PLUGIN, ACTION_PLUGIN):
            try:
                unload(p)
            except GLib.Error:
                pass


if __name__ == "__main__":
    main()
