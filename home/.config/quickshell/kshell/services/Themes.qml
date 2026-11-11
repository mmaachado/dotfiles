pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// KShell themes (config/themes.json), applied desktop-wide by kshelld.
// The applying itself happens in services/Scheme.qml, which reconciles the
// requested theme and Material colours against what theme.json says is applied.
Singleton {
    id: root

    property var list: []
    // What theme.json says is applied.
    property string current: "slate"
    // The scheme the apps were last painted with ("" = the theme's own colours).
    property string appliedScheme: ""
    property bool loaded: false
    // Theme picked in the picker, until theme.json catches up.
    property string requested: ""
    readonly property string target: requested || current

    // services/Scheme.qml applies it, with the Material colours if they're on.
    function apply(id: string): void {
        root.requested = id;
        Scheme.reconcile();
    }

    // Switch between the light and dark version of the current look: same
    // blur, opposite brightness. Remembers what was picked last for each.
    property var lastOf: ({})
    function toggleDark(): void {
        const cur = root.list.find(t => t.id === root.target);
        if (!cur)
            return;
        root.lastOf[cur.dark] = cur.id;
        const want = !cur.dark;
        const remembered = root.list.find(t => t.id === root.lastOf[want] && t.blur === cur.blur);
        const next = remembered ?? root.list.find(t => t.dark === want && t.blur === cur.blur)
            ?? root.list.find(t => t.dark === want);
        if (next)
            root.apply(next.id);
    }

    function rgb(c: var): color {
        return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1);
    }

    FileView {
        path: Quickshell.shellDir + "/config/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            let themes;
            try {
                themes = JSON.parse(text()).themes;
            } catch (e) {
                return; // empty mid-write; the next change reloads it
            }
            const byId = {};
            for (const t of themes)
                byId[t.id] = t;
            for (const t of themes)
                if (t.base && !t.palette)
                    t.palette = byId[t.base].palette;
            root.list = themes;
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/kshell/theme.json"
        printErrors: false // absent until the first theme is applied
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const t = JSON.parse(text());
                root.current = t.id;
                root.appliedScheme = t.scheme ?? "";
            } catch (e) {}
            if (root.requested === root.current)
                root.requested = "";
            root.loaded = true;
        }
        onLoadFailed: root.loaded = true
    }
}
