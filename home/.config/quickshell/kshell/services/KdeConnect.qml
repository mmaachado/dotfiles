pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Phones paired with KDE Connect (kdeconnectd): who's reachable, sending
// them text or files, and keeping the clipboard in sync with them.
//
// Clipboard sync is KDE Connect's own clipboard plugin. With it on, a copy
// on the phone lands on the desktop clipboard (and so in KShell's history)
// and desktop copies reach the phone. Settings.options.clipboardPhoneSync
// turns the plugin on or off for every paired device.
Singleton {
    id: root

    // [{ id, name }] of paired devices that are reachable now.
    property var devices: []
    readonly property bool available: devices.length > 0
    readonly property bool sync: Settings.options.clipboardPhoneSync

    function refresh(): void {
        if (!list.running)
            list.running = true;
    }

    function shareText(text: string): void {
        for (const d of root.devices)
            Quickshell.execDetached(["kdeconnect-cli", "-d", d.id, "--share-text", text]);
    }

    function shareFile(path: string): void {
        for (const d of root.devices)
            Quickshell.execDetached(["kdeconnect-cli", "-d", d.id, "--share", path]);
    }

    // Turn the clipboard plugin on or off for every paired device.
    function applySync(): void {
        for (const d of root.devices)
            Quickshell.execDetached(["qdbus6", "org.kde.kdeconnect", `/modules/kdeconnect/devices/${d.id}`,
                "org.kde.kdeconnect.device.setPluginEnabled", "kdeconnect_clipboard", String(root.sync)]);
    }

    onSyncChanged: applySync()
    onDevicesChanged: applySync()

    Process {
        id: list
        running: true
        // Paired and reachable: "<id> <name>" per line.
        command: ["kdeconnect-cli", "--list-available", "--id-name-only"]
        stdout: StdioCollector {
            onStreamFinished: {
                const devices = text.split("\n").filter(l => l.trim()).map(l => {
                    const sp = l.indexOf(" ");
                    return { id: l.slice(0, sp), name: l.slice(sp + 1) };
                });
                if (JSON.stringify(devices) !== JSON.stringify(root.devices))
                    root.devices = devices;
            }
        }
    }

    // kdeconnectd has no simple "devices changed" signal for us; phones come
    // and go with Wi-Fi, so look again now and then.
    Timer {
        running: true
        repeat: true
        interval: 15000
        onTriggered: root.refresh()
    }
}
