pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

Singleton {
    id: root

    property bool launcher
    property bool dashboard
    property bool session
    property bool wallpapers
    property bool themes
    property bool clipboard
    property bool dnd
    // Name of the screen the drawers open on (empty = any)
    property string screen: ""

    readonly property bool anyOpen: launcher || dashboard || session || wallpapers || themes || clipboard

    // The dashboard lives in the notch, so where the notch is kept to the
    // primary display it opens there.
    function screenFor(name: string, screenName: string): string {
        if (name === "dashboard" && Settings.options.notchDisplays === "primary" && Displays.primary)
            return Displays.primary;
        return screenName || Bridge.activeScreen;
    }

    function toggle(name: string, screenName: string): void {
        const was = root[name];
        closeAll();
        if (!was) {
            root.screen = root.screenFor(name, screenName);
            root[name] = true;
        }
    }

    function show(name: string, screenName: string): void {
        if (root[name] && root.screen === root.screenFor(name, screenName))
            return;
        closeAll();
        root.screen = root.screenFor(name, screenName);
        root[name] = true;
    }

    function closeAll(): void {
        launcher = false;
        dashboard = false;
        session = false;
        wallpapers = false;
        themes = false;
        clipboard = false;
    }

    Connections {
        target: Bridge
        function onIpc(target: string, fn: string): void {
            if (fn !== "toggle")
                return;
            if (target === "settings")
                Settings.toggle();
            else
                root.toggle(target, "");
        }
    }

    IpcHandler {
        target: "launcher"
        function toggle(): void { root.toggle("launcher", ""); }
    }
    IpcHandler {
        target: "dashboard"
        function toggle(): void { root.toggle("dashboard", ""); }
    }
    IpcHandler {
        target: "session"
        function toggle(): void { root.toggle("session", ""); }
    }
    IpcHandler {
        target: "wallpapers"
        function toggle(): void { root.toggle("wallpapers", ""); }
    }
    IpcHandler {
        target: "themes"
        function toggle(): void { root.toggle("themes", ""); }
    }
    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggle("clipboard", ""); }
    }
    IpcHandler {
        target: "settings"
        function toggle(): void { Settings.toggle(); }
        function open(): void { Settings.open = true; }
        function close(): void { Settings.open = false; }
        // `kshell ipc settings page dock`
        function page(name: string): void {
            const i = ["appearance", "notch", "tray", "dock", "wallpaper", "displays", "about"].indexOf(name.toLowerCase());
            if (i >= 0)
                Settings.page = i;
            Settings.open = true;
        }
    }
    IpcHandler {
        target: "drawers"
        function close(): void { root.closeAll(); }
    }
}
