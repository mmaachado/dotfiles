pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Wallpapers from ~/Pictures/Wallpapers (or the folder set in Settings). Plasma still owns the wallpaper:
// applying goes through plasma-apply-wallpaperimage, and the current one is
// read back from Plasma's config.
//
// Every screen's WallpaperTransition floods from what it shows to `target`
// (the wallpaper being previewed in the picker, else `current`). Plasma is
// only told once the flood has finished, so its own crossfade happens out of
// sight underneath the overlay.
Singleton {
    id: root

    // Emitted when a wallpaper is applied; screens call commit(to) once
    // their flood towards it is done.
    signal changing(to: string)
    property string pending: ""

    readonly property string dir: Settings.options.wallpaperDir || Quickshell.env("HOME") + "/Pictures/Wallpapers"
    onDirChanged: refresh()
    property list<string> files: []
    property string current: ""
    // What Plasma actually shows.
    property string applied: ""
    // Wallpaper highlighted in the picker, shown on the desktop until applied
    // or the picker closes.
    property string preview: ""
    readonly property string target: preview || current
    property bool scanned: false

    function refresh(): void {
        if (!scan.running)
            scan.running = true;
    }

    function apply(path: string): void {
        // Set current before clearing preview so `target` never flips back.
        root.current = path;
        root.preview = "";
        if (path === root.applied && !root.pending)
            return;
        root.pending = path;
        root.changing(path);
        fallback.restart();
    }

    // Hand the wallpaper to Plasma. Several screens may call this; only the
    // first call for the pending wallpaper does anything.
    function commit(path: string): void {
        if (path !== root.pending)
            return;
        root.pending = "";
        root.applied = path;
        fallback.stop();
        Quickshell.execDetached(["plasma-apply-wallpaperimage", path]);
    }

    // qs ipc call wallpaper set /path/to/image.jpg
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { root.apply(path); }
        function get(): string { return root.current; }
    }

    // In case no transition runs (e.g. an image fails to load).
    Timer {
        id: fallback
        interval: 8000
        onTriggered: root.commit(root.pending)
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
            if (m && !root.pending) {
                root.applied = decodeURIComponent(m[1].replace(/^file:\/\//, ""));
                root.current = root.applied;
            }
        }
    }
}
