pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through PowerDevil (laptop panels and DDC/CI monitors),
// relayed by `kshelld brightness`. Controls the internal panel if there is
// one, else the first display.
Singleton {
    id: root

    property var displays: []
    readonly property var display: displays.find(d => d.internal) ?? displays[0] ?? null
    readonly property bool available: display !== null && display.max > 0
    readonly property real value: available ? display.brightness / display.max : 0

    // A display's brightness changed. `own` = set by KShell itself.
    signal changed(real value, bool own)

    function set(v: real): void {
        if (available && proc.running)
            proc.write(`set ${display.name} ${Math.max(0, Math.min(1, v)).toFixed(4)}\n`);
    }

    readonly property string icon: value < 0.34 ? "display-brightness-low-symbolic"
        : value < 0.67 ? "display-brightness-medium-symbolic" : "display-brightness-high-symbolic"

    Process {
        id: proc
        running: true
        stdinEnabled: true
        command: [Bridge.kshelld, "brightness"]
        stdout: SplitParser {
            onRead: line => {
                const sp = line.indexOf(" ");
                const kind = line.slice(0, sp);
                const rest = line.slice(sp + 1);
                if (kind === "state") {
                    try {
                        root.displays = JSON.parse(rest);
                    } catch (e) {}
                } else if (kind === "changed") {
                    const [name, frac, who] = rest.split(" ");
                    if (name === root.display?.name)
                        root.changed(parseFloat(frac), who === "kshell");
                }
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: proc.running = true
    }
}
