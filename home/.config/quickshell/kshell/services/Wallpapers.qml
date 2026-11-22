pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Wallpapers from ~/Pictures/Wallpapers (or the folder set in Settings). Plasma still owns the wallpaper:
// it's set and read back per display through Plasma's scripting API, where
// each desktop containment belongs to a screen, matched to ours by geometry.
//
// Settings.options.wallpaperMode picks whether a wallpaper goes on every
// display ("same") or only the one the picker was opened on ("per-display").
//
// Every screen's WallpaperTransition floods from what it shows to
// targetFor(screen) (the wallpaper being previewed in the picker, else the
// screen's current one). Plasma is only told once the flood has finished, so
// its own crossfade happens out of sight underneath the overlay.
Singleton {
    id: root

    // Emitted when a wallpaper is applied; screens call commit(to, screen)
    // once their flood towards it is done.
    signal changing(to: string)

    readonly property string dir: Settings.options.wallpaperDir || Quickshell.env("HOME") + "/Pictures/Wallpapers"
    onDirChanged: refresh()
    property list<string> files: []
    property bool scanned: false

    readonly property bool perDisplay: Settings.options.wallpaperMode === "per-display"

    // Per screen name. Always replaced, never mutated, so bindings update.
    // What each screen should show.
    property var currentFor: ({})
    // What Plasma actually shows.
    property var appliedFor: ({})
    // Applied but not yet handed to Plasma.
    property var pendingFor: ({})

    // The primary display's wallpaper: Material colours follow it.
    readonly property string current: currentFor[Displays.primary] ?? Object.values(currentFor).find(p => p) ?? ""

    // Wallpaper highlighted in the picker, shown on the desktop until applied
    // or the picker closes; on one screen, or all ("").
    property string preview: ""
    property string previewScreen: ""

    function currentOn(screen: string): string {
        return root.currentFor[screen] ?? root.current;
    }
    function appliedOn(screen: string): string {
        return root.appliedFor[screen] ?? "";
    }
    function targetFor(screen: string): string {
        if (root.preview && (root.previewScreen === "" || root.previewScreen === screen))
            return root.preview;
        return root.currentFor[screen] ?? "";
    }

    // The screens a pick from the picker opened on `screen` goes to.
    function screensFor(screen: string): list<string> {
        if (!root.perDisplay)
            return Quickshell.screens.map(s => s.name);
        return [screen || Displays.primary];
    }

    function setPreview(path: string, screen: string): void {
        root.previewScreen = root.perDisplay ? (screen || Displays.primary) : "";
        root.preview = path;
    }

    function refresh(): void {
        if (!scan.running)
            scan.running = true;
    }

    function withKey(map: var, key: string, value: var): var {
        const m = Object.assign({}, map);
        if (value === undefined)
            delete m[key];
        else
            m[key] = value;
        return m;
    }

    function apply(path: string, screen: string): void {
        const screens = root.screensFor(screen);
        let current = Object.assign({}, root.currentFor);
        let pending = Object.assign({}, root.pendingFor);
        for (const s of screens) {
            current[s] = path;
            if (path !== root.appliedFor[s] || pending[s])
                pending[s] = path;
        }
        // Set current before clearing preview so a target never flips back.
        root.currentFor = current;
        root.preview = "";
        root.pendingFor = pending;
        if (screens.some(s => pending[s] === path)) {
            root.changing(path);
            fallback.restart();
        }
    }

    // Hand a screen's wallpaper to Plasma, once its flood is done.
    function commit(path: string, screen: string): void {
        if (root.pendingFor[screen] !== path)
            return;
        root.pendingFor = root.withKey(root.pendingFor, screen, undefined);
        root.appliedFor = root.withKey(root.appliedFor, screen, path);
        const s = Quickshell.screens.find(q => q.name === screen);
        if (s)
            root.plasma(`
                const url = ${JSON.stringify(root.url(path))};
                for (const d of desktops()) {
                    const g = d.screen >= 0 ? screenGeometry(d.screen) : null;
                    if (!g || g.x !== ${s.x} || g.y !== ${s.y})
                        continue;
                    d.wallpaperPlugin = "org.kde.image";
                    d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
                    d.writeConfig("Image", url);
                }`);
        if (Object.keys(root.pendingFor).length === 0)
            fallback.stop();
    }

    function plasma(script: string): void {
        Quickshell.execDetached(["qdbus6", "org.kde.plasmashell", "/PlasmaShell",
            "org.kde.PlasmaShell.evaluateScript", script]);
    }

    // qs ipc call wallpaper set /path/to/image.jpg
    // qs ipc call wallpaper setOn /path/to/image.jpg HDMI-A-2
    IpcHandler {
        target: "wallpaper"
        function set(path: string): void { root.apply(path, ""); }
        function setOn(path: string, screen: string): void {
            // An explicit screen always means just that one.
            let current = root.withKey(root.currentFor, screen, path);
            root.currentFor = current;
            if (path !== root.appliedFor[screen]) {
                root.pendingFor = root.withKey(root.pendingFor, screen, path);
                root.changing(path);
                fallback.restart();
            }
        }
        function get(): string { return root.current; }
        function getOn(screen: string): string { return root.currentFor[screen] ?? ""; }
    }

    // In case no transition runs (e.g. an image fails to load).
    Timer {
        id: fallback
        interval: 8000
        onTriggered: {
            for (const [s, p] of Object.entries(root.pendingFor))
                root.commit(p, s);
        }
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

    // ── Reading back what Plasma shows ───────────────────────────────

    function readBack(): void {
        if (!readProc.running)
            readProc.running = true;
        else
            readAgain.restart();
    }

    Timer {
        id: readAgain
        interval: 300
        onTriggered: root.readBack()
    }

    Process {
        id: readProc
        command: ["qdbus6", "org.kde.plasmashell", "/PlasmaShell", "org.kde.PlasmaShell.evaluateScript", `
            const out = [];
            for (const d of desktops()) {
                if (d.screen < 0)
                    continue;
                const g = screenGeometry(d.screen);
                d.currentConfigGroup = ["Wallpaper", "org.kde.image", "General"];
                out.push(JSON.stringify({ x: g.x, y: g.y, image: d.wallpaperPlugin === "org.kde.image" ? d.readConfig("Image") : "" }));
            }
            print(out.join("\\n"));`]
        stdout: StdioCollector {
            onStreamFinished: {
                let applied = Object.assign({}, root.appliedFor);
                let current = Object.assign({}, root.currentFor);
                for (const line of text.split("\n")) {
                    let d;
                    try {
                        d = JSON.parse(line);
                    } catch (e) {
                        continue;
                    }
                    const s = Quickshell.screens.find(q => q.x === d.x && q.y === d.y);
                    if (!s)
                        continue;
                    const path = d.image ? decodeURIComponent(String(d.image).replace(/^file:\/\//, "")) : "";
                    applied[s.name] = path;
                    if (!root.pendingFor[s.name])
                        current[s.name] = path;
                }
                root.appliedFor = applied;
                root.currentFor = current;
            }
        }
    }

    // Plasma writes its config when the wallpaper changes, from here or elsewhere.
    FileView {
        path: Quickshell.env("HOME") + "/.config/plasma-org.kde.plasma.desktop-appletsrc"
        watchChanges: true
        onFileChanged: root.readBack()
        onLoaded: root.readBack()
    }

    // Plasma moves desktops between screens when displays change.
    Connections {
        target: Quickshell
        function onScreensChanged(): void { readAgain.restart(); }
    }
    Variants {
        model: Quickshell.screens
        Connections {
            required property ShellScreen modelData
            target: modelData
            function onGeometryChanged(): void { readAgain.restart(); }
        }
    }
}
