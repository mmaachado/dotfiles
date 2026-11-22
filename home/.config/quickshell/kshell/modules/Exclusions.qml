import QtQuick
import Quickshell
import qs.config

// Invisible layer surfaces that reserve space, so maximised windows sit inside
// the frame (KWin honours layer-shell exclusive zones like panel struts).
Scope {
    id: root

    required property ShellScreen screen
    // Each side's frame: the bar's width on its side, else the border.
    property real leftZone: Appearance.sizes.barWidth
    property real topZone: Appearance.sizes.border
    property real rightZone: Appearance.sizes.border
    property real bottomZone: Appearance.sizes.border

    component Strut: PanelWindow {
        screen: root.screen
        color: "transparent"
        mask: Region {}
        implicitWidth: 1
        implicitHeight: 1
    }

    Strut {
        anchors { left: true; top: true; bottom: true }
        exclusiveZone: root.leftZone
    }
    Strut {
        anchors { top: true; left: true; right: true }
        exclusiveZone: root.topZone
    }
    Strut {
        anchors { right: true; top: true; bottom: true }
        exclusiveZone: root.rightZone
    }
    Strut {
        anchors { bottom: true; left: true; right: true }
        exclusiveZone: root.bottomZone
    }
}
