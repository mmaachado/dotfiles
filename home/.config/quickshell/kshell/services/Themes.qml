pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// KShell themes (config/themes.json), applied desktop-wide by bridge/themes.py.
Singleton {
    id: root

    property var list: []
    property string current: "slate"

    function apply(id: string): void {
        root.current = id;
        Quickshell.execDetached(["python3", "-I", Quickshell.shellDir + "/bridge/themes.py", "apply", id]);
    }

    function rgb(c: var): color {
        return Qt.rgba(c[0] / 255, c[1] / 255, c[2] / 255, 1);
    }

    FileView {
        path: Quickshell.shellDir + "/config/themes.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const themes = JSON.parse(text()).themes;
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
                root.current = JSON.parse(text()).id;
            } catch (e) {}
        }
    }
}
