pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property bool launcher
    property bool dashboard
    property bool session
    property bool wallpapers
    property bool themes
    property bool dnd
    // Name of the screen the drawers open on (empty = any)
    property string screen: ""

    readonly property bool anyOpen: launcher || dashboard || session || wallpapers || themes

    function toggle(name: string, screenName: string): void {
        const was = root[name];
        closeAll();
        if (!was) {
            root.screen = screenName || Bridge.activeScreen;
            root[name] = true;
        }
    }

    function show(name: string, screenName: string): void {
        if (root[name] && root.screen === screenName)
            return;
        closeAll();
        root.screen = screenName || Bridge.activeScreen;
        root[name] = true;
    }

    function closeAll(): void {
        launcher = false;
        dashboard = false;
        session = false;
        wallpapers = false;
        themes = false;
    }

    Connections {
        target: Bridge
        function onIpc(target: string, fn: string): void {
            if (fn === "toggle")
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
        target: "drawers"
        function close(): void { root.closeAll(); }
    }
}
