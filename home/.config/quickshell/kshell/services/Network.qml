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
    // Each link on its own, for the bar's separate Ethernet / Wi-Fi icons.
    property bool ethernetConnected: false
    property bool wifiConnected: false
    property string wifiName: ""

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

    readonly property string wifiIcon: {
        if (!wifiEnabled)
            return "network-wireless-off";
        if (!wifiConnected)
            return "network-wireless-disconnected-symbolic";
        if (strength >= 80) return "network-wireless-signal-excellent-symbolic";
        if (strength >= 55) return "network-wireless-signal-good-symbolic";
        if (strength >= 30) return "network-wireless-signal-ok-symbolic";
        return "network-wireless-signal-weak-symbolic";
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
                // Ethernet wins for `type`/`name` (the dashboard's single link).
                let type = "none", name = "", eth = false, wl = false, wlName = "";
                for (const l of devs.trim().split("\n")) {
                    const [t, st, ...conn] = l.split(":");
                    if (st !== "connected")
                        continue;
                    if (t === "ethernet" && !eth) {
                        eth = true;
                        type = "ethernet";
                        name = conn.join(":");
                    } else if (t === "wifi" && !wl) {
                        wl = true;
                        wlName = conn.join(":");
                        if (!eth) {
                            type = "wifi";
                            name = wlName;
                        }
                    }
                }
                const active = (wifi ?? "").split("\n").find(l => l.startsWith("yes:"));
                root.strength = active ? parseInt(active.split(":")[1]) : 0;
                root.type = type;
                root.ethernetConnected = eth;
                root.wifiConnected = wl;
                root.wifiName = wlName;
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
        running: root.wifiConnected
        repeat: true
        onTriggered: root.refresh()
    }
}
