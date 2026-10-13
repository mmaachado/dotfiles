pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Window / virtual-desktop state from KWin, via bridge/bridge.py + bridge.js.
Singleton {
    id: root

    property var desktops: []
    property string current: ""
    property string activeScreen: ""
    property var windows: []
    // Stable first-seen ordering so the task list doesn't reshuffle on focus changes.
    property var order: ({})
    property int counter: 0

    readonly property int currentIndex: desktops.findIndex(d => d.id === current)
    readonly property var activeWindow: windows.find(w => w.active) ?? null
    readonly property var currentWindows: windows.filter(w => w.desktops.length === 0 || w.desktops.includes(current))

    signal ipc(string target, string fn)

    function send(cmd: string): void {
        if (proc.running)
            proc.write(cmd + "\n");
    }
    function activate(id: string): void { send("activate " + id); }
    function toggle(id: string): void { send("toggle " + id); }
    function close(id: string): void { send("close " + id); }
    function switchDesktop(id: string): void { send("desktop " + id); }
    function cycleDesktop(delta: int): void {
        if (desktops.length === 0)
            return;
        const i = Math.max(0, Math.min(desktops.length - 1, currentIndex + delta));
        switchDesktop(desktops[i].id);
    }
    function hasWindows(desktopId: string): bool {
        return windows.some(w => w.desktops.length === 0 || w.desktops.includes(desktopId));
    }

    Process {
        id: proc
        running: true
        stdinEnabled: true
        command: ["python3", "-I", Quickshell.shellDir + "/bridge/bridge.py"]
        stdout: SplitParser {
            onRead: line => {
                const sp = line.indexOf(" ");
                const kind = line.slice(0, sp);
                const rest = line.slice(sp + 1);
                if (kind === "state") {
                    const s = JSON.parse(rest);
                    root.desktops = s.desktops;
                    root.current = s.current;
                    root.activeScreen = s.screen;
                    for (const w of s.windows)
                        if (!(w.id in root.order))
                            root.order[w.id] = root.counter++;
                    root.windows = s.windows.sort((a, b) => root.order[a.id] - root.order[b.id]);
                } else if (kind === "ipc") {
                    const [target, fn] = rest.split(" ");
                    root.ipc(target, fn);
                }
            }
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 2000
        onTriggered: proc.running = true
    }
}
