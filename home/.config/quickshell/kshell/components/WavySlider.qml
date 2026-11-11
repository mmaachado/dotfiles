import QtQuick
import QtQuick.Shapes
import qs.config

// Material 3 Expressive slider: the filled part is a sine wave, then a gap,
// a flat track, and a vertical handle between them. The wave flattens
// (on a spring) while dragging, and can drift while something plays.
//
// Same API as StyledSlider: value 0..1, moved(v), icon + iconClicked.
Item {
    id: root

    property real value: 0
    property string icon: ""
    // Wave drifts along (e.g. a seek bar while playing).
    property bool flowing: false
    property bool wavy: true
    property real wavelength: 26
    property real amplitude: 3.2
    property color activeColor: Appearance.colors.primary
    property color trackColor: Appearance.colors.secondaryContainer
    signal moved(real value)
    signal iconClicked

    implicitHeight: 32

    readonly property real stroke: 4
    readonly property real handleW: 4
    readonly property real gap: 6
    readonly property real iconSpace: icon !== "" ? 30 : 0
    readonly property real span: width - iconSpace
    readonly property real handleX: iconSpace + span * Math.max(0, Math.min(1, value))
    readonly property real cy: height / 2

    // Flattens while dragged; grows back afterwards.
    Spring {
        id: amp
        target: root.wavy && !drag.pressed ? root.amplitude : 0
        preset: Appearance.spring.defaultSpatial
        epsilon: 0.01
    }

    property real phase: 0
    FrameAnimation {
        running: root.flowing && root.visible && Appearance.motion > 0
        onTriggered: root.phase = (root.phase + frameTime * 2.4 / Math.max(Appearance.motion, 0.01)) % (Math.PI * 2)
    }

    Icon {
        visible: root.icon !== ""
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        name: root.icon
        size: 20
        color: Appearance.colors.text

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: root.iconClicked()
        }
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        // Active part: a sine wave from the start to just before the handle.
        ShapePath {
            strokeColor: root.activeColor
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin

            PathPolyline {
                path: {
                    const x0 = root.iconSpace + root.stroke / 2;
                    const x1 = Math.max(x0, root.handleX - root.gap - root.stroke / 2);
                    const pts = [];
                    const a = amp.value, k = 2 * Math.PI / root.wavelength;
                    for (let x = x0; x < x1; x += 2)
                        pts.push(Qt.point(x, root.cy + a * Math.sin(k * (x - x0) - root.phase)));
                    pts.push(Qt.point(x1, root.cy + a * Math.sin(k * (x1 - x0) - root.phase)));
                    return pts;
                }
            }
        }

        // Remaining track: flat.
        ShapePath {
            strokeColor: root.trackColor
            strokeWidth: root.stroke
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            startX: Math.min(root.width - root.stroke / 2, root.handleX + root.gap + root.stroke / 2)
            startY: root.cy
            PathLine { x: root.width - root.stroke / 2; y: root.cy }
        }
    }

    // Handle
    Rectangle {
        x: root.handleX - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: root.handleW
        height: drag.pressed ? root.height - 2 : root.height - 8
        radius: width / 2
        color: root.activeColor

        Behavior on height { NumberAnimation { duration: Appearance.anim.fast } }
    }

    MouseArea {
        id: drag
        anchors.fill: parent
        anchors.leftMargin: root.iconSpace
        cursorShape: Qt.PointingHandCursor
        function update(x: real): void {
            root.moved(Math.max(0, Math.min(1, x / width)));
        }
        onPressed: mouse => update(mouse.x)
        onPositionChanged: mouse => { if (pressed) update(mouse.x); }
        onWheel: wheel => root.moved(Math.max(0, Math.min(1, root.value + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))))
    }
}
