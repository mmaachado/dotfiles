pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Display configuration from KScreen, via kscreen-doctor (which talks to
// KScreen over D-Bus, so KScreen keeps persisting the layout itself).
//
// Changes that could leave a screen unusable (mode, scale, position,
// disabling) are applied with a confirm: unless keep() is called within
// `confirmSeconds`, the previous configuration is restored.
Singleton {
    id: root

    // Connected outputs: { name, enabled, primary, rotation, x, y, width,
    // height (rotated pixels), scale, modeId, modes: [{ id, width, height, refresh }] }
    property var outputs: []
    readonly property var enabledOutputs: outputs.filter(o => o.enabled)
    readonly property string primary: {
        const p = outputs.filter(o => o.enabled).sort((a, b) => a.priority - b.priority)[0];
        return p?.name ?? Quickshell.screens[0]?.name ?? "";
    }

    // Pending confirmation: the arguments that undo the last risky change.
    property var revertArgs: null
    readonly property bool confirming: revertArgs !== null
    readonly property int confirmSeconds: 15
    property int confirmLeft: 0

    readonly property var rotations: ({ 1: "none", 2: "left", 4: "inverted", 8: "right" })

    function output(name: string): var {
        return outputs.find(o => o.name === name) ?? null;
    }
    function isPrimary(name: string): bool {
        return name === primary;
    }

    function refresh(): void {
        if (!query.running)
            query.running = true;
    }

    // Logical size, what the compositor lays out (rotated, then scaled).
    function logical(o: var): size {
        return Qt.size(Math.round(o.width / o.scale), Math.round(o.height / o.scale));
    }

    // ── Changes ──────────────────────────────────────────────────────

    function setPrimary(name: string): void {
        run([`output.${name}.priority.1`]);
    }

    // rotation: none | left | inverted | right
    function setRotation(name: string, rotation: string): void {
        const o = output(name);
        if (!o || rotations[o.rotation] === rotation)
            return;
        risky([`output.${name}.rotation.${rotation}`], [`output.${name}.rotation.${rotations[o.rotation]}`]);
    }

    function setMode(name: string, modeId: string): void {
        const o = output(name);
        if (!o || o.modeId === modeId)
            return;
        risky([`output.${name}.mode.${modeId}`], [`output.${name}.mode.${o.modeId}`]);
    }

    function setScale(name: string, scale: real): void {
        const o = output(name);
        if (!o || Math.abs(o.scale - scale) < 0.001)
            return;
        risky([`output.${name}.scale.${scale}`], [`output.${name}.scale.${o.scale}`]);
    }

    function setEnabled(name: string, on: bool): void {
        const o = output(name);
        if (!o || o.enabled === on)
            return;
        // Never switch off the last screen.
        if (!on && enabledOutputs.length <= 1)
            return;
        risky([`output.${name}.${on ? "enable" : "disable"}`], [`output.${name}.${on ? "disable" : "enable"}`]);
    }

    // positions: { name: Qt.point(x, y) } in logical pixels, for every output
    // that moves. Normalised so the layout starts at 0,0.
    function setPositions(positions: var): void {
        const names = Object.keys(positions);
        if (names.length === 0)
            return;
        const minX = Math.min(...enabledOutputs.map(o => positions[o.name]?.x ?? o.x));
        const minY = Math.min(...enabledOutputs.map(o => positions[o.name]?.y ?? o.y));
        const args = [], undo = [];
        for (const o of enabledOutputs) {
            const p = positions[o.name] ?? Qt.point(o.x, o.y);
            const x = Math.round(p.x - minX), y = Math.round(p.y - minY);
            if (x === o.x && y === o.y)
                continue;
            args.push(`output.${o.name}.position.${x},${y}`);
            undo.push(`output.${o.name}.position.${o.x},${o.y}`);
        }
        if (args.length)
            risky(args, undo);
    }

    function keep(): void {
        root.revertArgs = null;
        countdown.stop();
    }

    function revert(): void {
        const undo = root.revertArgs;
        keep();
        if (undo)
            run(undo);
    }

    function risky(args: var, undo: var): void {
        // A second change while one is pending: undo both if neither is kept.
        root.revertArgs = (root.revertArgs ?? []).concat(undo);
        root.confirmLeft = root.confirmSeconds;
        countdown.restart();
        run(args);
    }

    // kscreen-doctor calls are queued so a burst of changes applies in order.
    property var queue: []
    function run(args: var): void {
        root.queue = root.queue.concat([args]);
        next();
    }
    function next(): void {
        if (apply.running || root.queue.length === 0)
            return;
        apply.command = ["kscreen-doctor", ...root.queue[0]];
        root.queue = root.queue.slice(1);
        apply.running = true;
    }

    Timer {
        id: countdown
        interval: 1000
        repeat: true
        onTriggered: {
            if (--root.confirmLeft <= 0)
                root.revert();
        }
    }

    Process {
        id: apply
        onExited: {
            root.refresh();
            root.next();
        }
    }

    Process {
        id: query
        running: true
        command: ["kscreen-doctor", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let data;
                try {
                    data = JSON.parse(text);
                } catch (e) {
                    return;
                }
                root.outputs = data.outputs.filter(o => o.connected).map(o => {
                    const mode = o.modes.find(m => m.id === o.currentModeId);
                    return {
                        name: o.name,
                        enabled: o.enabled,
                        priority: o.priority,
                        rotation: o.rotation,
                        x: o.pos.x,
                        y: o.pos.y,
                        width: o.size.width,
                        height: o.size.height,
                        scale: o.scale,
                        modeId: o.currentModeId,
                        refresh: mode ? mode.refreshRate : 0,
                        modes: o.modes.map(m => ({
                            id: m.id,
                            width: m.size.width,
                            height: m.size.height,
                            refresh: m.refreshRate,
                        })).sort((a, b) => b.width * b.height - a.width * a.height || b.refresh - a.refresh),
                    };
                }).sort((a, b) => a.x - b.x || a.y - b.y);
            }
        }
    }

    // Hotplug, rotation and mode changes all show up as screen changes.
    Connections {
        target: Quickshell
        function onScreensChanged(): void { root.refresh(); }
    }
    Variants {
        model: Quickshell.screens
        Connections {
            required property ShellScreen modelData
            target: modelData
            function onGeometryChanged(): void { root.refresh(); }
            function onOrientationChanged(): void { root.refresh(); }
        }
    }

    // qs ipc call displays refresh
    IpcHandler {
        target: "displays"
        function refresh(): void { root.refresh(); }
        function primary(): string { return root.primary; }
        function keep(): void { root.keep(); }
        function revert(): void { root.revert(); }
    }
}
