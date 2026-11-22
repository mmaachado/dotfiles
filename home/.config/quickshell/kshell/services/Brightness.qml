pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness through PowerDevil (laptop panels and DDC/CI monitors),
// relayed by `kshelld brightness`. Every display PowerDevil can dim is listed
// on its own, so each monitor gets its own slider and OSD gauge. The
// brightness keys go through PowerDevil, which steps every display at once.
Singleton {
    id: root

    // [{ name, label, brightness, max, internal, value (0..1) }], internal panel first.
    property var displays: []
    readonly property bool available: displays.some(d => d.max > 0)
    // The internal panel if there is one, else the first display.
    readonly property var display: displays[0] ?? null
    readonly property real value: display && display.max > 0 ? display.brightness / display.max : 0
    // The average, for single-value places (icons).
    readonly property real average: displays.length
        ? displays.reduce((sum, d) => sum + d.value, 0) / displays.length : 0

    // A display's brightness changed. `own` = set by KShell itself (sliders),
    // false for the keys and other apps.
    signal changed(string name, real value, bool own)

    function set(name: string, v: real): void {
        if (proc.running)
            proc.write(`set ${name} ${Math.max(0, Math.min(1, v)).toFixed(4)}\n`);
    }
    function setAll(v: real): void {
        for (const d of root.displays)
            root.set(d.name, v);
    }

    function iconFor(v: real): string {
        return v < 0.34 ? "display-brightness-low-symbolic"
            : v < 0.67 ? "display-brightness-medium-symbolic" : "display-brightness-high-symbolic";
    }
    readonly property string icon: iconFor(average)

    // A short name for a monitor, for the OSD: the first word of
    // PowerDevil's label ("BenQ GW2480" → "BenQ", "G270Q180").
    function shortLabel(d: var): string {
        if (d.internal)
            return "Built-in";
        return (d.label || d.name).trim().split(/\s+/)[0];
    }

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
                        root.displays = JSON.parse(rest)
                            .filter(d => d.max > 0)
                            .map(d => Object.assign(d, { value: d.brightness / d.max }))
                            .sort((a, b) => b.internal - a.internal || a.name.localeCompare(b.name, undefined, { numeric: true }));
                    } catch (e) {}
                } else if (kind === "changed") {
                    const [name, frac, who] = rest.split(" ");
                    root.changed(name, parseFloat(frac), who === "kshell");
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
