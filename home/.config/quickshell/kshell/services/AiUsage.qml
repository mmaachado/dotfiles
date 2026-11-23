pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// AI plan usage from ai-usagebar (`ai-usagebar usage --json`, schema 1):
// Claude, Codex, Copilot and the others it supports. ai-usagebar caches
// and rate-limits itself; this asks every 5 minutes, and when the popup
// opens. Providers that aren't set up (errors) are left out.
Singleton {
    id: root

    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/ai-usagebar"
    property bool installed: false
    // Shown when switched on in the settings and ai-usagebar is installed.
    readonly property bool shown: Settings.options.aiUsage && installed

    // [{ name, plan, metrics: [{ label, percent, detail, severity }] }]
    property var providers: []
    // The most used metric: { name, label, percent }, or null.
    readonly property var top: {
        let best = null;
        for (const p of providers)
            for (const m of p.metrics)
                if (!best || m.percent > best.percent)
                    best = { name: p.name, label: m.label, percent: m.percent };
        return best;
    }
    property string error: ""
    // `qs ipc call aiusage toggle`: the indicator on the active screen opens.
    signal toggleRequested
    property string updated: ""

    function refresh(): void {
        if (root.installed && !usage.running)
            usage.running = true;
    }

    function configure(): void {
        Quickshell.execDetached(["sh", "-c",
            'f="$HOME/.config/ai-usagebar/config.toml"; [ -f "$f" ] || { mkdir -p "${f%/*}"; touch "$f"; }; exec xdg-open "$f"']);
    }

    function parse(text: string): void {
        let data;
        try {
            data = JSON.parse(text);
        } catch (e) {
            root.error = "ai-usagebar returned something unexpected";
            return;
        }
        root.providers = (data.entries ?? [])
            .filter(e => e.status === "ready" && (e.metrics ?? []).length > 0)
            .map(e => ({
                name: e.display_name || e.name,
                plan: e.plan ?? "",
                metrics: e.metrics.filter(m => typeof m.percent === "number").map(m => ({
                    label: m.label ?? "",
                    percent: m.percent,
                    detail: m.detail ?? "",
                    severity: m.severity ?? "",
                })),
            }));
        root.error = "";
        root.updated = Qt.formatTime(new Date(), "hh:mm");
    }

    Process {
        id: check
        running: true
        command: ["test", "-x", root.bin]
        onExited: code => {
            root.installed = code === 0;
            root.refresh();
        }
    }

    Process {
        id: usage
        command: [root.bin, "usage", "--json"]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim()) root.parse(text)
        }
    }

    Timer {
        running: root.shown
        repeat: true
        interval: 5 * 60 * 1000
        onTriggered: root.refresh()
    }

    IpcHandler {
        target: "aiusage"
        function toggle(): void { root.toggleRequested(); }
        function refresh(): void { root.refresh(); }
    }

    // ai-usagebar installed later (./install.py packages -g ai)? Look again
    // when the setting is switched on.
    Connections {
        target: Settings.options
        function onAiUsageChanged(): void {
            if (!check.running)
                check.running = true;
        }
    }
}
