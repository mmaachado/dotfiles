pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// On-screen display. Plasma still decides when one is due (volume and
// brightness keys, mic mute, keyboard layout, power profile, ...); `kshelld
// osd` relays each event and modules/Osd.qml draws it in the frame. The KWin
// bridge hides Plasma's own OSD window meanwhile.
Singleton {
    id: root

    readonly property bool enabled: Settings.options.osd
    property bool shown: false
    // progress | text | brightness (one gauge per monitor, from Brightness)
    property string kind: "progress"
    property string icon: ""
    property string text: ""
    property real value: 0

    Process {
        id: proc
        running: root.enabled
        command: [Bridge.kshelld, "osd"]
        stdinEnabled: true // closing it on exit stops kshelld
        stdout: SplitParser {
            onRead: line => {
                let e;
                try {
                    e = JSON.parse(line);
                } catch (err) {
                    return;
                }
                // Brightness gets its own per-monitor OSD (below); with several
                // monitors Plasma only sends a line of text for it.
                if (/^(video-)?display-brightness/.test(e.icon ?? ""))
                    return;
                root.kind = e.kind;
                root.icon = e.icon;
                root.text = e.text ?? "";
                if (e.kind === "progress")
                    root.value = e.max > 0 ? e.value / e.max : 0;
                root.shown = true;
                hide.restart();
            }
        }
        onExited: if (root.enabled) restart.start()
    }

    // Brightness keys (and other apps): show every monitor's level. Changes
    // made from KShell's own sliders don't need an OSD.
    Connections {
        target: Brightness
        function onChanged(name: string, value: real, own: bool): void {
            if (!root.enabled || own)
                return;
            root.kind = "brightness";
            root.icon = Brightness.icon;
            root.shown = true;
            hide.restart();
        }
    }

    Timer {
        id: hide
        interval: 1600
        onTriggered: root.shown = false
    }

    Timer {
        id: restart
        interval: 5000
        onTriggered: proc.running = root.enabled
    }
}
