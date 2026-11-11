pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

// Material 3 colours (Settings → Appearance → Colours). `kshelld scheme` builds
// the scheme from the wallpaper or the theme's accent into
// ~/.local/state/kshell/scheme.json, which config/Appearance.qml reads.
//
// With "Recolour apps" on, the theme is applied desktop-wide with the scheme's
// colours. That is reconciled against state on disk, never fired blindly:
// theme.json records which scheme the apps were painted with, and a re-apply
// only happens when that differs from what the settings want. So a shell
// restart changes nothing, while switching back to the KDE source restores
// the theme's own colours.
Singleton {
    id: root

    readonly property string file: Quickshell.env("HOME") + "/.local/state/kshell/scheme.json"
    readonly property string source: Settings.options.colorSource
    readonly property bool active: source === "wallpaper" || source === "theme"
    readonly property string variant: Settings.options.schemeVariant
    readonly property bool apps: Settings.options.schemeApps

    readonly property var theme: Themes.list.find(t => t.id === Themes.target) ?? null
    readonly property bool dark: theme?.dark ?? true
    readonly property string seed: theme ? hex(theme.palette.accent) : ""
    readonly property string wallpaper: Wallpapers.current

    // What scheme.json on disk was built from (null until read / if missing).
    property var built: null
    property bool loaded: false

    function hex(c: var): string {
        return "#" + c.map(v => v.toString(16).padStart(2, "0")).join("");
    }

    // The scheme the settings ask for, or null if there's nothing to build from.
    function wanted(): var {
        if (source === "wallpaper" && wallpaper)
            return { args: ["--wallpaper", wallpaper], wallpaper: wallpaper, seed: null };
        if (source === "theme" && seed)
            return { args: ["--seed", seed], wallpaper: null, seed: seed };
        return null;
    }

    function matches(w: var): bool {
        const b = root.built;
        return b !== null && b.variant === root.variant && b.dark === root.dark
            && (w.wallpaper ? b.wallpaper === w.wallpaper : (b.wallpaper === null && b.source === w.seed));
    }

    function reconcile(): void {
        debounce.restart();
    }

    onActiveChanged: reconcile()
    onVariantChanged: reconcile()
    onAppsChanged: reconcile()
    onDarkChanged: reconcile()
    onSeedChanged: reconcile()
    onWallpaperChanged: reconcile()
    Connections {
        target: Themes
        function onLoadedChanged() { root.reconcile(); }
        function onTargetChanged() { root.reconcile(); }
        function onAppliedSchemeChanged() { root.reconcile(); }
    }

    // Coalesces the burst of property changes at startup and on theme switches.
    Timer {
        id: debounce
        interval: 80
        onTriggered: {
            if (!root.loaded || !Themes.loaded || Themes.list.length === 0)
                return;
            if (gen.running || paint.running) {
                debounce.restart(); // look again once that's done
                return;
            }

            // 1. Build the scheme the settings ask for.
            const w = root.active ? root.wanted() : null;
            if (w && !root.matches(w)) {
                gen.command = [Bridge.kshelld, "scheme", ...w.args, "--variant", root.variant,
                    root.dark ? "--dark" : "--light", "--out", root.file];
                gen.running = true;
                return; // scheme.json changes → loaded again → reconcile
            }

            // 2. Paint the apps with it (or with the theme's own colours).
            const key = w && root.apps && root.built ? `${root.built.source}|${root.built.variant}|${root.built.dark}` : "";
            if (Themes.target === Themes.current && key === Themes.appliedScheme)
                return;
            const cmd = [Bridge.kshelld, "theme", "--themes", Quickshell.shellDir + "/config/themes.json",
                "apply", Themes.target];
            paint.command = key ? [...cmd, "--scheme", root.file] : cmd;
            paint.running = true; // theme.json changes → reconcile → nothing left to do
        }
    }

    Process {
        id: gen
        stderr: StdioCollector {
            onStreamFinished: if (text) console.warn("kshelld scheme:", text.trim())
        }
    }

    Process {
        id: paint
        stderr: StdioCollector {
            onStreamFinished: if (text) console.warn("kshelld theme:", text.trim())
        }
    }

    FileView {
        path: root.file
        printErrors: false // absent until the first scheme is built
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const s = JSON.parse(text());
                root.built = { variant: s.variant, dark: s.dark, wallpaper: s.wallpaper, source: s.source };
            } catch (e) {
                root.built = null;
            }
            root.loaded = true;
            root.reconcile();
        }
        onLoadFailed: {
            root.built = null;
            root.loaded = true;
            root.reconcile();
        }
    }
}
