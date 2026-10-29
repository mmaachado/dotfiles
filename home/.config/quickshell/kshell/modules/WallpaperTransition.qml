import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import qs.config
import qs.services

// Transition between wallpapers (effects in shaders/, picked in Settings). A
// click-through surface on the Bottom layer (over the Plasma desktop, under
// windows) floods from what it shows to
// Wallpapers.target: the wallpaper being previewed in the picker, else the
// current one. Once a flood towards an applied wallpaper ends, Plasma is told
// to switch underneath, and the surface fades away.
//
// Images load asynchronously, so the shader samples from a pool of three
// slots: an image on screen is never replaced until what takes its place has
// loaded (otherwise the shader draws an empty texture, i.e. a black frame).
Scope {
    id: root

    required property ShellScreen screen
    // Match the Backdrop blur while an app has focus.
    property bool blurred

    property string to: ""
    property bool running: false
    property bool mapped: false // hidden until the first images have loaded
    property bool waiting: false // for the `to` image to load
    property bool snapping: false // for a mid-flood snapshot to load
    property var grab: null // keeps a snapshot's image alive
    property int seq: 0
    // Shader in use (shaders/<effect>.frag). Only changed while the surface
    // is hidden, so a shader swap never costs a visible frame.
    property string effect: "liquid"
    readonly property list<string> effects: ["liquid", "fade", "wipe", "circle", "pixelate", "dissolve"]

    readonly property list<Image> slots: [s0, s1, s2]
    property Image fromSlot: s0
    property Image toSlot: s1
    property Image snapSlot: null

    component Slot: Image {
        visible: false
        asynchronous: true
        cache: false
        fillMode: Image.PreserveAspectCrop
        // Snapshots from grabToImage are already screen-sized.
        sourceSize: String(source).startsWith("file:") ? Qt.size(root.screen.width, root.screen.height) : undefined
        onStatusChanged: {
            root.trySnap();
            root.tryStart();
        }
    }

    readonly property string target: Wallpapers.target
    onTargetChanged: go()

    Connections {
        target: Wallpapers

        // Applying the wallpaper that's already on show (picked from a preview).
        function onChanging(to: string): void {
            if (root.running && !root.waiting && !root.snapping && !anim.running && root.to === to)
                root.settle();
        }
    }

    function freeSlot(...used): Image {
        return root.slots.find(s => !used.includes(s));
    }

    function go(): void {
        const t = root.target;
        if (!t)
            return;
        if (!root.running) {
            if (t === Wallpapers.applied)
                return;
            root.running = true;
            const e = Settings.options.transitionEffect;
            root.effect = e === "random" ? root.effects[Math.floor(Math.random() * root.effects.length)]
                : root.effects.includes(e) ? e : "liquid";
            root.fromSlot = s0;
            s0.source = Wallpapers.url(Wallpapers.applied || t);
            fx.progress = 0;
            stage.opacity = 1;
            floodTo(t);
            return;
        }
        if (t === root.to && (anim.running || root.waiting || root.snapping))
            return;
        hold.stop();
        fadeOut.stop();
        stage.opacity = 1;
        if (anim.running || root.snapping) {
            // Changed course mid-flood: freeze, snapshot the frame on screen
            // and flood onwards from it.
            anim.stop();
            root.snapping = true;
            const n = ++root.seq;
            fx.grabToImage(r => {
                if (n !== root.seq)
                    return;
                root.grab = r;
                root.snapSlot = root.freeSlot(root.fromSlot, root.toSlot);
                root.snapSlot.source = r.url;
                root.trySnap();
            });
        } else if (root.waiting) {
            // Nothing of the old target is on screen yet (progress is 0).
            floodTo(t);
        } else if (t !== root.to) {
            // Idle, showing `to` in full.
            root.fromSlot = root.toSlot;
            fx.progress = 0;
            floodTo(t);
        } else {
            settle();
        }
    }

    // Start loading `t` into a slot that isn't on screen, then flood to it.
    function floodTo(t: string): void {
        root.to = t;
        if (root.toSlot === root.fromSlot)
            root.toSlot = root.freeSlot(root.fromSlot);
        root.toSlot.source = Wallpapers.url(t);
        root.waiting = true;
        tryStart();
    }

    function trySnap(): void {
        if (!root.snapping || !root.snapSlot || root.snapSlot.status === Image.Loading)
            return;
        root.snapping = false;
        root.fromSlot = root.snapSlot.status === Image.Ready ? root.snapSlot : root.toSlot;
        root.snapSlot = null;
        fx.progress = 0;
        floodTo(root.target);
    }

    function tryStart(): void {
        if (!root.waiting || root.fromSlot.status === Image.Loading || root.toSlot.status === Image.Loading)
            return;
        root.waiting = false;
        if (root.toSlot.status !== Image.Ready) {
            stop();
            Wallpapers.commit(root.to);
            return;
        }
        root.mapped = true;
        anim.start();
    }

    // Flood finished: hand an applied wallpaper to Plasma, and once Plasma
    // shows what we show, fade out. Previews just stay up.
    function settle(): void {
        Wallpapers.commit(root.to);
        if (root.to === Wallpapers.applied)
            hold.restart();
    }

    function stop(): void {
        root.running = false;
        root.mapped = false;
        root.waiting = false;
        root.snapping = false;
        root.grab = null;
        for (const s of root.slots)
            s.source = "";
    }

    PanelWindow {
        id: win

        visible: root.mapped
        screen: root.screen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        mask: Region {}
        WlrLayershell.namespace: "kshell-wallpaper"
        WlrLayershell.layer: WlrLayer.Bottom
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        Slot { id: s0 }
        Slot { id: s1 }
        Slot { id: s2 }

        Item {
            id: stage
            anchors.fill: parent

            // Always layered, so toggling the blur doesn't drop a frame.
            layer.enabled: true
            layer.effect: MultiEffect {
                autoPaddingEnabled: false
                blurEnabled: root.blurred
                blur: 1
                blurMax: 64
            }

            ShaderEffect {
                id: fx

                property real progress: 0
                property vector2d resolution: Qt.vector2d(width, height)
                property vector2d fromSize: Qt.vector2d(root.fromSlot.implicitWidth, root.fromSlot.implicitHeight)
                property vector2d toSize: Qt.vector2d(root.toSlot.implicitWidth, root.toSlot.implicitHeight)
                property var fromTex: root.fromSlot
                property var toTex: root.toSlot

                anchors.fill: parent
                fragmentShader: Qt.resolvedUrl(`../shaders/${root.effect}.frag.qsb`)
            }

            Rectangle {
                anchors.fill: parent
                color: Qt.alpha(Appearance.base, 0.18)
                visible: root.blurred
            }
        }
    }

    NumberAnimation {
        id: anim
        target: fx
        property: "progress"
        from: 0
        to: 1
        // A zero-length flood when the transition is off: previews and
        // wallpaper changes still go through here, they just swap instantly.
        duration: Settings.options.wallpaperTransition ? Math.round(Settings.options.transitionDuration * Appearance.motion) : 0
        easing.type: Easing.InOutCubic
        onFinished: root.settle()
    }

    // Leave time for Plasma to load the image and finish its own crossfade.
    Timer {
        id: hold
        interval: 1500
        onTriggered: fadeOut.start()
    }

    NumberAnimation {
        id: fadeOut
        target: stage
        property: "opacity"
        to: 0
        duration: Appearance.anim.slow
        onFinished: root.stop()
    }
}
