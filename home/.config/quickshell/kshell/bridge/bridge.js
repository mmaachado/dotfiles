// KWin script loaded by kshelld bridge. Pushes window/desktop state to the
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
        fullscreen: w.fullScreen,
        maximized: w.maximizeMode === 3, // MaximizeFull
        x: Math.round(w.frameGeometry.x),
        y: Math.round(w.frameGeometry.y),
        width: Math.round(w.frameGeometry.width),
        height: Math.round(w.frameGeometry.height),
        output: w.output ? w.output.name : "",
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
    for (const s of ["captionChanged", "minimizedChanged", "desktopsChanged", "skipTaskbarChanged", "outputChanged", "fullScreenChanged", "maximizedChanged", "interactiveMoveResizeFinished"])
        if (w[s]) w[s].connect(push);
    // Geometry (for the notch merging into a top bar): skip the stream of
    // updates during an interactive drag; interactiveMoveResizeFinished sends
    // the final position.
    if (w.frameGeometryChanged)
        w.frameGeometryChanged.connect(() => { if (!w.move && !w.resize) push(); });
}

// Plasma's OSD (volume / brightness keys, ...) is hidden while KShell draws
// its own: plasmashell keeps deciding *when* to show one, kshelld relays
// that, and the window itself is made invisible here. The flag lives in the
// bridge (Settings → OSD); it's cached so a new OSD window is hidden before
// its first frame, and refreshed whenever one appears.
let hideOsd = false;
function plasmaOsd(w) {
    return w.onScreenDisplay && w.resourceName === "plasmashell";
}
function applyOsd() {
    for (const w of arr(workspace.windowList()))
        if (plasmaOsd(w))
            w.opacity = hideOsd ? 0 : 1;
}
function refreshOsd() {
    callDBus(SVC, PATH, IFACE, "HidePlasmaOsd", v => {
        if (!!v !== hideOsd) {
            hideOsd = !!v;
            applyOsd();
        }
    });
}

arr(workspace.windowList()).forEach(hook);
workspace.windowAdded.connect(w => {
    if (plasmaOsd(w)) {
        w.opacity = hideOsd ? 0 : 1;
        refreshOsd();
        return;
    }
    hook(w);
    push();
refreshOsd();
});
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
registerShortcut("KShell Wallpapers", "KShell: Toggle wallpaper picker", "Meta+W", ipc("wallpapers toggle"));
registerShortcut("KShell Themes", "KShell: Toggle theme picker", "Meta+Shift+T", ipc("themes toggle"));
registerShortcut("KShell Clipboard", "KShell: Toggle clipboard history", "Meta+V", ipc("clipboard toggle"));
// macOS's screenshot keys: everything, a region, the capture toolbar.
// `kshelld shortcuts kshell` adds the other spellings (Meta+Shift+3, ...)
// and moves Print from Spectacle to the region screenshot.
registerShortcut("KShell Screenshot", "KShell: Screenshot of everything", "Meta+#", ipc("capture full"));
registerShortcut("KShell Screenshot Region", "KShell: Screenshot of a region", "Print", ipc("capture region"));
registerShortcut("KShell Capture Toolbar", "KShell: Toggle capture toolbar", "Meta+%", ipc("capture toggle"));
registerShortcut("KShell Settings", "KShell: Toggle settings", "", ipc("settings toggle"));
registerShortcut("KShell Session", "KShell: Toggle session menu", "", ipc("session toggle"));

push();
refreshOsd();
