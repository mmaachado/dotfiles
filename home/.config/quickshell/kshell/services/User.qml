pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The logged-in user, for the control center's greeting.
Singleton {
    id: root

    readonly property string login: Quickshell.env("USER")
    property string fullName: ""
    readonly property string firstName: (fullName || login).split(" ")[0]
    // AccountsService picture (System Settings → Users), else ~/.face.
    readonly property string avatar: "/var/lib/AccountsService/icons/" + login
    readonly property string faceFallback: Quickshell.env("HOME") + "/.face"

    property int uptimeMinutes: 0
    readonly property string uptime: {
        const d = Math.floor(uptimeMinutes / 1440), h = Math.floor(uptimeMinutes % 1440 / 60), m = uptimeMinutes % 60;
        return d > 0 ? `${d}d ${h}h` : h > 0 ? `${h}h ${m}m` : `${m}m`;
    }

    readonly property string greeting: {
        const h = Time.now.getHours();
        return h < 5 ? "Good night" : h < 12 ? "Good morning" : h < 18 ? "Good afternoon" : "Good evening";
    }

    // Only ticks while something shows it.
    property int users: 0

    Process {
        running: true
        command: ["getent", "passwd", root.login]
        stdout: StdioCollector {
            onStreamFinished: root.fullName = (text.split(":")[4] ?? "").split(",")[0].trim()
        }
    }

    FileView {
        id: uptime
        path: "/proc/uptime"
        onLoaded: root.uptimeMinutes = Math.floor(parseFloat(text().split(" ")[0]) / 60)
    }

    Timer {
        running: root.users > 0
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: uptime.reload()
    }
}
