import QtQuick
import qs.config

// A damped spring: `value` chases `target`, keeping its velocity when the
// target moves mid-flight (Material 3 Expressive motion). Parameters are the
// Android / material-motion ones: stiffness and damping ratio (1 = no
// overshoot, lower bounces). Presets are in Appearance.spring.
//
//     Spring { id: s; target: open ? 1 : 0; preset: Appearance.spring.defaultSpatial }
//     height: content.height * s.value
//
// Time is scaled by KDE's animation speed; with animations off it snaps.
Item {
    id: root

    property real target: 0
    property real value: 0
    property real velocity: 0
    // [stiffness, dampingRatio]; or set the two directly.
    property var preset: Appearance.spring.defaultSpatial
    property real stiffness: preset[0]
    property real dampingRatio: preset[1]
    // Settled when this close to the target (in the value's units) and slow.
    property real epsilon: 0.001
    readonly property bool moving: frame.running

    // Jump without animating.
    function snap(v: real): void {
        frame.running = false;
        root.velocity = 0;
        root.value = v;
    }

    // Push the value away by `delta` and let it spring back to the target
    // (FLIP: something moved, show it travelling from where it was).
    function displace(delta: real): void {
        if (Appearance.motion <= 0)
            return;
        root.value += delta;
        frame.running = true;
    }

    visible: false
    Component.onCompleted: snap(target)
    onTargetChanged: {
        if (Appearance.motion <= 0)
            snap(target);
        else if (!frame.running)
            frame.running = true;
    }

    FrameAnimation {
        id: frame
        onTriggered: {
            // Seconds of motion this frame; capped so a stalled frame can't explode.
            let left = Math.min(frame.frameTime, 0.05) / Math.max(Appearance.motion, 0.01);
            const k = root.stiffness;
            const c = 2 * root.dampingRatio * Math.sqrt(k);
            let x = root.value;
            let v = root.velocity;
            const to = root.target;
            while (left > 0) {
                const h = Math.min(left, 1 / 480); // semi-implicit Euler, small steps
                v += (-k * (x - to) - c * v) * h;
                x += v * h;
                left -= h;
            }
            if (Math.abs(x - to) < root.epsilon && Math.abs(v) < root.epsilon * 10) {
                x = to;
                v = 0;
                frame.running = false;
            }
            root.velocity = v;
            root.value = x;
        }
    }
}
