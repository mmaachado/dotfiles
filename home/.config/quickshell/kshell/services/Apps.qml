pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    readonly property list<DesktopEntry> all: DesktopEntries.applications.values
        .filter(a => !a.noDisplay)
        .sort((a, b) => a.name.localeCompare(b.name))

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
