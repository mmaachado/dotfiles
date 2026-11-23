pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Clipboard history, kept by `kshelld clipboard` (ext-data-control): text
// and image copies, newest first, with pins. Password managers' copies are
// skipped.
Singleton {
    id: root

    // [{id, kind: "text" | "image", text, path, width, height, pinned, time}]
    property var history: []

    function send(cmd: string): void {
        if (proc.running)
            proc.write(cmd + "\n");
    }
    function copy(id: int): void { send(`copy ${id}`); }
    function pin(id: int): void { send(`pin ${id}`); }
    function remove(id: int): void { send(`delete ${id}`); }
    function clear(): void { send("clear"); }

    Process {
        id: proc
        running: true
        stdinEnabled: true
        command: [Bridge.kshelld, "clipboard"]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => {
                if (!line.startsWith("history "))
                    return;
                try {
                    root.history = JSON.parse(line.slice(8));
                } catch (e) {}
            }
        }
        stderr: StdioCollector {
            onStreamFinished: if (text) console.warn("kshelld clipboard:", text.trim())
        }
        onExited: restart.start()
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: proc.running = true
    }
}
