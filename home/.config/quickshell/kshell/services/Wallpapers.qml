pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Wallpapers from ~/Pictures/Wallpapers. Plasma still owns the wallpaper:
// applying goes through plasma-apply-wallpaperimage, and the current one is
// read back from Plasma's config.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/Pictures/Wallpapers"
    property list<string> files: []
    property string current: ""
    property bool scanned: false

    function refresh(): void {
        if (!scan.running)
            scan.running = true;
    }

    function apply(path: string): void {
        Quickshell.execDetached(["plasma-apply-wallpaperimage", path]);
        root.current = path;
    }

    function name(path: string): string {
        const base = path.slice(path.lastIndexOf("/") + 1);
        const dot = base.lastIndexOf(".");
        return dot > 0 ? base.slice(0, dot) : base;
    }

    function url(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function openFolder(): void {
        Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", root.dir]);
    }

    Process {
        id: scan
        command: ["find", "-L", root.dir, "-maxdepth", "2", "-type", "f",
            "-iregex", ".*\\.\\(jpe?g\\|png\\|webp\\|avif\\|bmp\\)"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.files = text.split("\n").filter(f => f).sort((a, b) => a.localeCompare(b));
                root.scanned = true;
            }
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.config/plasma-org.kde.plasma.desktop-appletsrc"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            const m = text().match(/\[org\.kde\.image\]\[General\][^\[]*?\nImage=([^\n]+)/);
            if (m)
                root.current = decodeURIComponent(m[1].replace(/^file:\/\//, ""));
        }
    }
}
