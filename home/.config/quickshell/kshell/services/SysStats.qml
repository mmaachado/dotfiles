pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Only poll while something is showing the numbers.
    property int users: 0

    property real cpu: 0
    property real mem: 0
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real disk: 0

    property var lastCpu: null

    Timer {
        interval: 2000
        running: root.users > 0
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            stat.reload();
            meminfo.reload();
            if (!df.running)
                df.running = true;
        }
    }

    FileView {
        id: stat
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1).map(Number);
            const idle = f[3] + f[4];
            const total = f.reduce((a, b) => a + b, 0);
            if (root.lastCpu) {
                const dt = total - root.lastCpu.total;
                root.cpu = dt > 0 ? 1 - (idle - root.lastCpu.idle) / dt : 0;
            }
            root.lastCpu = { idle, total };
        }
    }

    FileView {
        id: meminfo
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const total = parseInt(t.match(/MemTotal:\s+(\d+)/)[1]);
            const avail = parseInt(t.match(/MemAvailable:\s+(\d+)/)[1]);
            root.memTotalGiB = total / 1048576;
            root.memUsedGiB = (total - avail) / 1048576;
            root.mem = 1 - avail / total;
        }
    }

    Process {
        id: df
        command: ["df", "--output=pcent", "/"]
        stdout: StdioCollector {
            onStreamFinished: root.disk = parseInt(text.split("\n")[1]) / 100
        }
    }
}
