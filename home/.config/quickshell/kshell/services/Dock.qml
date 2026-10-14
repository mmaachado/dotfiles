pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pinned apps + running windows grouped by app, like Plasma's icon task manager.
// Pins live in config/pinned.json (right-click an icon in the bar to pin/unpin).
Singleton {
    id: root

    property list<string> pinned: []

    readonly property var groups: {
        const out = root.pinned.map(id => ({ id, pinned: true, windows: [] }));
        for (const w of Bridge.currentWindows) {
            const id = root.appKey(w);
            let g = out.find(g => g.id === id);
            if (!g) {
                g = { id, pinned: false, windows: [] };
                out.push(g);
            }
            g.windows.push(w);
        }
        return out;
    }

    function norm(id: string): string {
        return (id ?? "").replace(/\.desktop$/, "");
    }

    // Reading `applications` makes callers' bindings re-evaluate once the
    // (asynchronously loaded) desktop-entry database is ready.
    function entry(id: string): DesktopEntry {
        void DesktopEntries.applications.values;
        return DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id);
    }

    // Desktop-file id for a KWin window, so windows match their pinned launcher.
    function appKey(win: var): string {
        void DesktopEntries.applications.values;
        const e = (win.appId && DesktopEntries.byId(win.appId)) || DesktopEntries.heuristicLookup(win.cls);
        return norm(e?.id || win.appId || win.cls);
    }

    function icon(group: var): string {
        return entry(group.id)?.icon || (group.windows[0] ? Apps.iconFor(group.windows[0]) : group.id);
    }

    function name(group: var): string {
        if (group.windows.length === 1)
            return group.windows[0].title;
        return entry(group.id)?.name ?? group.id;
    }

    function launch(group: var): void {
        Quickshell.execDetached(["kstart", "--application", group.id]);
    }

    function activate(group: var): void {
        const ws = group.windows;
        if (ws.length === 0)
            return launch(group);
        if (ws.length === 1)
            return Bridge.toggle(ws[0].id);
        // Several windows: cycle to the one after the active one.
        const i = ws.findIndex(w => w.active);
        Bridge.activate(ws[(i + 1) % ws.length].id);
    }

    function togglePin(id: string): void {
        root.pinned = root.pinned.includes(id) ? root.pinned.filter(p => p !== id) : [...root.pinned, id];
        file.setText(JSON.stringify(root.pinned, null, 2) + "\n");
    }

    FileView {
        id: file
        path: Quickshell.shellDir + "/config/pinned.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.pinned = JSON.parse(text()).map(root.norm);
            } catch (e) {
                console.warn("pinned.json:", e);
            }
        }
    }
}
