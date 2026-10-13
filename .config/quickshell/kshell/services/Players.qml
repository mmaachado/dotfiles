pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris

Singleton {
    id: root

    readonly property list<MprisPlayer> list: Mpris.players.values
    property MprisPlayer manual: null
    readonly property MprisPlayer active: (manual && list.includes(manual)) ? manual : (list.find(p => p.isPlaying) ?? list[0] ?? null)

    function formatTime(s: real): string {
        s = Math.max(0, Math.floor(s));
        const m = Math.floor(s / 60);
        return `${m}:${String(s % 60).padStart(2, "0")}`;
    }

    // MPRIS doesn't push position updates; poll while playing.
    Timer {
        interval: 1000
        running: root.active?.isPlaying ?? false
        repeat: true
        onTriggered: root.active.positionChanged()
    }
}
