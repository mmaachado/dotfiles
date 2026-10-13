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

    // Best-effort icon for a window reported by KWin.
    function iconFor(win: var): string {
        void DesktopEntries.applications.values; // re-evaluate when entries load
        const entry = (win.appId && DesktopEntries.byId(win.appId)) || DesktopEntries.heuristicLookup(win.cls);
        return entry?.icon || win.appId || win.cls || "application-x-executable";
    }
}
