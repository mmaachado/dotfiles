// KWin script loaded by bridge.py. Pushes window/desktop state to the
// org.kshell.Bridge DBus service and registers KShell global shortcuts.
const SVC = "org.kshell.Bridge", PATH = "/org/kshell/Bridge", IFACE = "org.kshell.Bridge";

function arr(list) {
    const out = [];
    for (let i = 0; i < list.length; i++) out.push(list[i]);
    return out;
}

function relevant(w) {
    return w.normalWindow && !w.skipTaskbar && !w.deleted;
}

function info(w) {
    return {
        id: w.internalId.toString(),
        title: w.caption,
        appId: w.desktopFileName || "",
        cls: w.resourceClass || "",
        desktops: w.onAllDesktops ? [] : arr(w.desktops).map(d => d.id),
        minimized: w.minimized,
        active: w === workspace.activeWindow,
    };
}

function push() {
    const state = {
        desktops: arr(workspace.desktops).map(d => ({ id: d.id, name: d.name })),
        current: workspace.currentDesktop ? workspace.currentDesktop.id : "",
        screen: workspace.activeScreen ? workspace.activeScreen.name : "",
        windows: arr(workspace.windowList()).filter(relevant).map(info),
    };
    callDBus(SVC, PATH, IFACE, "Update", JSON.stringify(state));
}

function hook(w) {
    for (const s of ["captionChanged", "minimizedChanged", "desktopsChanged", "skipTaskbarChanged", "outputChanged"])
        if (w[s]) w[s].connect(push);
}

arr(workspace.windowList()).forEach(hook);
workspace.windowAdded.connect(w => { hook(w); push(); });
workspace.windowRemoved.connect(push);
workspace.windowActivated.connect(push);
workspace.currentDesktopChanged.connect(push);
workspace.desktopsChanged.connect(push);
for (const d of arr(workspace.desktops)) d.nameChanged.connect(push);

function ipc(cmd) {
    return () => callDBus(SVC, PATH, IFACE, "Ipc", cmd);
}
registerShortcut("KShell Launcher", "KShell: Toggle app launcher", "Meta+Space", ipc("launcher toggle"));
registerShortcut("KShell Dashboard", "KShell: Toggle dashboard", "Meta+Alt+D", ipc("dashboard toggle"));
registerShortcut("KShell Session", "KShell: Toggle session menu", "", ipc("session toggle"));

push();
