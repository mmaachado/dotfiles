pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager status through nmcli (refreshed on `nmcli monitor` events).
Singleton {
    id: root

    property string type: "none" // wifi | ethernet | none
    property string name: ""
    property int strength: 0
    property bool wifiEnabled: true

    readonly property string icon: {
        if (type === "ethernet")
            return "network-wired-activated-symbolic";
        if (type === "wifi") {
            if (strength >= 80) return "network-wireless-signal-excellent-symbolic";
            if (strength >= 55) return "network-wireless-signal-good-symbolic";
            if (strength >= 30) return "network-wireless-signal-ok-symbolic";
            return "network-wireless-signal-weak-symbolic";
        }
        return "network-offline-symbolic";
    }

    function toggleWifi(): void {
        Quickshell.execDetached(["nmcli", "radio", "wifi", wifiEnabled ? "off" : "on"]);
    }

    function refresh(): void {
        if (!status.running)
            status.running = true;
    }

    Process {
        id: status
        running: true
        command: ["sh", "-c", "nmcli -t -f TYPE,STATE,CONNECTION device status; echo '--'; nmcli -t -f ACTIVE,SIGNAL dev wifi 2>/dev/null; echo '--'; nmcli radio wifi"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [devs, wifi, radio] = text.split("--\n");
                let type = "none", name = "";
                for (const l of devs.trim().split("\n")) {
                    const [t, st, ...conn] = l.split(":");
                    if (st !== "connected")
                        continue;
                    if (t === "ethernet") {
                        type = "ethernet";
                        name = conn.join(":");
                        break;
                    }
                    if (t === "wifi" && type === "none") {
                        type = "wifi";
                        name = conn.join(":");
                    }
                }
                const active = (wifi ?? "").split("\n").find(l => l.startsWith("yes:"));
                root.strength = active ? parseInt(active.split(":")[1]) : 0;
                root.type = type;
                root.name = name;
                root.wifiEnabled = (radio ?? "").trim() === "enabled";
            }
        }
    }

    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser {
            onRead: debounce.restart()
        }
    }

    Timer {
        id: debounce
        interval: 400
        onTriggered: root.refresh()
    }

    Timer {
        interval: 30000
        running: root.type === "wifi"
        repeat: true
        onTriggered: root.refresh()
    }
}
