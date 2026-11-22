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
    // progress | text
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
