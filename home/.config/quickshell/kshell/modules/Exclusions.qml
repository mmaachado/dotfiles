import QtQuick
import Quickshell
import qs.config

// Invisible layer surfaces that reserve space, so maximised windows sit inside
// the frame (KWin honours layer-shell exclusive zones like panel struts).
Scope {
    id: root

    required property ShellScreen screen

    component Strut: PanelWindow {
        screen: root.screen
        color: "transparent"
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }

    Strut {
        anchors { left: true; top: true; bottom: true }
        exclusiveZone: Appearance.sizes.barWidth
    }
    Strut {
        anchors { top: true; left: true; right: true }
        exclusiveZone: Appearance.sizes.border
    }
    Strut {
        anchors { right: true; top: true; bottom: true }
        exclusiveZone: Appearance.sizes.border
    }
    Strut {
        anchors { bottom: true; left: true; right: true }
        exclusiveZone: Appearance.sizes.border
    }
}
