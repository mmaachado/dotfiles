pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Phones connected through adb (USB or Wi-Fi debugging), for the Quick
// Settings tile, and opening droid Phone. Only polled while the dashboard
// is open, so adb isn't kept busy for nothing.
Singleton {
    id: root

    // Models of connected, authorised phones ("Pixel 8").
    property var phones: []
    readonly property bool connected: phones.length > 0
    readonly property string app: Quickshell.env("HOME") + "/.local/bin/droid-phone"

    function open(): void {
        Quickshell.execDetached(["sh", "-c", 'if [ -x "$1" ]; then exec "$1"; else exec scrcpy; fi', "sh", root.app]);
    }

    Process {
        id: list
        command: ["sh", "-c", "command -v adb >/dev/null && adb devices -l"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.phones = text.split("\n").slice(1)
                    .map(l => l.trim().split(/\s+/))
                    .filter(p => p[1] === "device")
                    .map(p => (p.find(f => f.startsWith("model:")) ?? `model:${p[0]}`).slice(6).replace(/_/g, " "));
            }
        }
    }

    Timer {
        running: Visibilities.dashboard
        repeat: true
        triggeredOnStart: true
        interval: 10000
        onTriggered: if (!list.running) list.running = true
    }

    // qs ipc call phone open
    IpcHandler {
        target: "phone"
        function open(): void { root.open(); }
    }
}
