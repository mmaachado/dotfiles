pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property list<DesktopEntry> all: DesktopEntries.applications.values
        .filter(a => !a.noDisplay && root.installed(a))
        .sort((a, b) => a.name.localeCompare(b.name))

    // ── Entries for apps that aren't installed ───────────────────────
    // Leftover .desktop files (an uninstalled Flatpak's launcher, a program
    // that's gone) still sit in the applications folders. `check` finds the
    // installed Flatpaks and the programs that can't be found; until it has
    // run, everything counts as installed.
    property var flatpaks: null // ids, or null before the first check
    property var missingPrograms: []

    function flatpakId(app: DesktopEntry): string {
        const cmd = app.command ?? [];
        const run = cmd.indexOf("run");
        if (!cmd.length || !String(cmd[0]).endsWith("flatpak") || run < 0)
            return "";
        return cmd.slice(run + 1).find(a => !String(a).startsWith("-") && !String(a).startsWith("@@")) ?? "";
    }

    function program(app: DesktopEntry): string {
        const cmd = app.command ?? [];
        let i = 0;
        // env VAR=value program ...
        if (cmd[0] === "env" || String(cmd[0]).endsWith("/env"))
            for (i = 1; i < cmd.length && String(cmd[i]).includes("="); i++) {}
        return cmd[i] ? String(cmd[i]) : "";
    }

    function installed(app: DesktopEntry): bool {
        const fp = root.flatpakId(app);
        if (fp && root.flatpaks !== null)
            return root.flatpaks.includes(fp);
        return !root.missingPrograms.includes(root.program(app));
    }

    readonly property var programs: {
        const set = new Set();
        for (const a of DesktopEntries.applications.values)
            if (!a.noDisplay && root.program(a))
                set.add(root.program(a));
        return [...set];
    }
    onProgramsChanged: recheck.restart()

    Timer {
        id: recheck
        interval: 500
        onTriggered: {
            check.running = false;
            check.running = true;
        }
    }

    Process {
        id: check
        command: ["sh", "-c", `
            flatpak list --app --columns=application 2>/dev/null
            echo --
            for p; do command -v "$p" >/dev/null 2>&1 || echo "$p"; done`, "sh", ...root.programs]
        stdout: StdioCollector {
            onStreamFinished: {
                const [fp, missing] = text.split("--\n");
                root.flatpaks = (fp ?? "").split("\n").filter(l => l);
                root.missingPrograms = (missing ?? "").split("\n").filter(l => l);
            }
        }
    }

    function score(app: DesktopEntry, q: string): int {
        const name = app.name.toLowerCase();
        if (name === q) return 1000;
        if (name.startsWith(q)) return 800;
        if (name.split(/[\s\-_.]/).some(w => w.startsWith(q))) return 600;
        if (name.includes(q)) return 400;
        const extra = [app.genericName, app.comment, app.id, ...(app.keywords ?? [])].join(" ").toLowerCase();
        if (extra.includes(q)) return 200;
        // Fuzzy subsequence match on the name
        let i = 0;
        for (const c of name)
            if (c === q[i]) i++;
        return i === q.length ? 100 : 0;
    }

    function query(text: string): list<DesktopEntry> {
        const q = text.trim().toLowerCase();
        if (!q)
            return all;
        return all.map(a => ({ a, s: score(a, q) }))
            .filter(x => x.s > 0)
            .sort((x, y) => y.s - x.s)
            .map(x => x.a);
    }

    // Launch through KIO so apps get Plasma's startup feedback and systemd scopes.
    function launch(app: DesktopEntry): void {
        Quickshell.execDetached(["kstart", "--application", app.id]);
    }

    // Desktop entry for an id, window class or app name. Some apps (Electron
    // ones like GitHub Desktop) report a class such as "GitHub Desktop" that
    // Quickshell's heuristic can't match, so also try a slug of it and the
    // entries' names / StartupWMClass.
    function lookup(key: string): DesktopEntry {
        const apps = DesktopEntries.applications.values; // re-evaluate when entries load
        if (!key)
            return null;
        const slug = key.toLowerCase().replace(/\s+/g, "-");
        const k = key.toLowerCase();
        return DesktopEntries.byId(key) || DesktopEntries.byId(slug) || DesktopEntries.heuristicLookup(key)
            || apps.find(a => a.startupClass.toLowerCase() === k || a.name.toLowerCase() === k) || null;
    }

    // Desktop entry for a window reported by KWin.
    function entryFor(win: var): DesktopEntry {
        return (win.appId && DesktopEntries.byId(win.appId)) || lookup(win.cls);
    }

    // Best-effort icon for a window.
    function iconFor(win: var): string {
        return entryFor(win)?.icon || win.appId || win.cls || "application-x-executable";
    }

    // App name for a window ("Firefox", "kitty"), not its title.
    function nameFor(win: var): string {
        return entryFor(win)?.name || win.cls || win.appId || win.title;
    }
}
