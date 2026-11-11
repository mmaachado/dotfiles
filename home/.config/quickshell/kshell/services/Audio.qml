pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    // PipeWire only reports a default once one has been configured; until
    // then (as pactl does) fall back to the first real device.
    readonly property PwNode sink: Pipewire.defaultAudioSink ?? sinks[0] ?? null
    readonly property PwNode source: Pipewire.defaultAudioSource ?? sources[0] ?? null
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    readonly property string icon: {
        if (muted || volume <= 0)
            return "audio-volume-muted-symbolic";
        if (volume < 0.34)
            return "audio-volume-low-symbolic";
        if (volume < 0.67)
            return "audio-volume-medium-symbolic";
        return "audio-volume-high-symbolic";
    }

    function setVolume(v: real): void {
        if (sink?.ready && sink.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1.5, v));
        }
    }
    readonly property bool hasMic: source !== null
    readonly property bool micMuted: source?.audio?.muted ?? false
    function toggleMic(): void {
        if (source?.ready && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Hardware devices (not app streams), for the Sound page.
    readonly property var sinks: (Pipewire.nodes?.values ?? []).filter(n => n.audio && n.isSink && !n.isStream)
    readonly property var sources: (Pipewire.nodes?.values ?? []).filter(n => n.audio && !n.isSink && !n.isStream)
    function setSink(n: PwNode): void { Pipewire.preferredDefaultAudioSink = n; }
    function setSource(n: PwNode): void { Pipewire.preferredDefaultAudioSource = n; }

    function toggleMute(): void {
        if (sink?.ready && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink, root.source]
    }
}
