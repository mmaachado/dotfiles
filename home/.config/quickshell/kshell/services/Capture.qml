pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Screenshots and screen recordings, macOS style, with Spectacle as the
// engine (it captures through KWin's ScreenShot2 and screencast APIs).
//
//   shot("full" | "screen" | "window" | "region")   capture, save, copy
//   record("screen" | "region" | "window"), stop()   record a video
//
// Screenshots go to Settings.options.screenshotDir (~/Pictures/Screenshots)
// as "Screenshot YYYY-MM-DD at HH.MM.SS.png" and are copied to the clipboard;
// `captured` then shows the floating thumbnail.
Singleton {
    id: root

    // Options from the capture toolbar (saved in settings.json).
    readonly property int delay: Settings.options.screenshotDelay
    readonly property bool pointer: Settings.options.screenshotPointer
    readonly property string dir: Settings.options.screenshotDir
        || Quickshell.env("HOME") + "/Pictures/Screenshots"

    property bool busy: false
    property bool recording: false
    property string recordMode: ""

    // A capture finished: the saved file (image or video).
    signal captured(string path, bool video)
    signal failed(string message)

    readonly property var flags: ({ full: "-f", screen: "-m", window: "-a", region: "-r" })

    function fileName(): string {
        return `${root.dir}/Screenshot ${Qt.formatDateTime(new Date(), "yyyy-MM-dd 'at' HH.mm.ss")}.png`;
    }

    function shot(mode: string): void {
        if (root.busy || root.recording || !(mode in root.flags))
            return;
        root.busy = true;
        const out = root.fileName();
        shooter.target = out;
        shooter.command = ["sh", "-c", 'mkdir -p "$1" && shift && exec spectacle "$@"', "sh", root.dir,
            "-b", "-n", "-c", root.flags[mode], "-o", out,
            ...(root.delay > 0 ? ["-d", String(root.delay * 1000)] : []),
            ...(root.pointer ? ["-p"] : [])];
        // Let a drawer that asked for this slide away first.
        startShot.restart();
    }

    Timer {
        id: startShot
        interval: 350
        onTriggered: shooter.running = true
    }

    Process {
        id: shooter
        property string target
        onExited: (code, status) => {
            root.busy = false;
            // Spectacle exits 0 even when a region pick is cancelled; the
            // file only exists if something was captured.
            check.path = shooter.target;
            check.running = true;
        }
    }

    Process {
        id: check
        property string path
        command: ["test", "-s", path]
        onExited: code => {
            if (code === 0)
                root.captured(check.path, false);
        }
    }

    // ── Recording ────────────────────────────────────────────────────

    readonly property var recordFlags: ({ screen: "s", region: "r", window: "w" })

    function record(mode: string): void {
        if (root.recording || root.busy || !(mode in root.recordFlags))
            return;
        root.recordMode = mode;
        recorder.command = ["spectacle", "-n", "-R", root.recordFlags[mode], ...(root.pointer ? ["-p"] : [])];
        startRecord.restart();
    }

    Timer {
        id: startRecord
        interval: 350
        onTriggered: {
            watcher.running = true;
            recorder.running = true;
            root.recording = true;
        }
    }

    // Asking Spectacle to record again stops the recording in progress.
    function stop(): void {
        if (!root.recording)
            return;
        Quickshell.execDetached(["qdbus6", "org.kde.Spectacle", "/", "org.kde.Spectacle.RecordScreen", "0"]);
    }

    Process {
        id: recorder
        onExited: {
            root.recording = false;
            stopWatching.restart();
        }
    }

    // Spectacle announces the saved video on D-Bus.
    Process {
        id: watcher
        command: ["dbus-monitor", "--session", "type='signal',interface='org.kde.Spectacle'"]
        property string member: ""
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/member=(\w+)/);
                if (m) {
                    watcher.member = m[1];
                    return;
                }
                const s = line.match(/^\s*string "(.*)"$/);
                if (!s)
                    return;
                if (watcher.member === "RecordingTaken")
                    root.captured(s[1], true);
                else if (watcher.member === "RecordingFailed")
                    root.failed(s[1]);
                watcher.member = "";
            }
        }
    }

    Timer {
        id: stopWatching
        interval: 3000
        onTriggered: watcher.running = false
    }

    // ── Shortcuts and IPC ────────────────────────────────────────────

    // Meta+Shift+3 / 4 (bridge.js) arrive as "capture full" / "capture region".
    Connections {
        target: Bridge
        function onIpc(target: string, fn: string): void {
            if (target !== "capture")
                return;
            if (fn in root.flags)
                root.shot(fn);
            else if (fn === "stop")
                root.stop();
        }
    }

    // qs ipc call capture shot region
    IpcHandler {
        target: "capture"
        function toggle(): void { Visibilities.toggle("capture", ""); }
        function shot(mode: string): void { root.shot(mode); }
        function record(mode: string): void { root.record(mode); }
        function stop(): void { root.stop(); }
    }
}
