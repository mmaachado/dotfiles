import QtQuick
import qs.config

// A panel that slides out of a frame edge. Put content inside; it's sized by
// the content's implicit size and revealed as `open` animates.
Item {
    id: root

    property string edge: "top"
    property bool open: false
    default property alias content: holder.data
    readonly property real r: Appearance.sizes.rounding
    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real contentLength: horizontal ? holder.childrenRect.width : holder.childrenRect.height
    readonly property real contentDepth: horizontal ? holder.childrenRect.height : holder.childrenRect.width
    property real progress: open ? 1 : 0
    readonly property real depth: (contentDepth + Appearance.sizes.padding * 2) * progress
    readonly property bool shown: progress > 0
    // The drawer body without its fillets (used for the blur region).
    readonly property Item body: bodyItem

    Behavior on progress {
        NumberAnimation {
            duration: root.open ? Appearance.anim.slow : Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.open ? Appearance.anim.enter : Appearance.anim.exit
        }
    }

    width: shape.width
    height: shape.height
    visible: shown

    DrawerShape {
        id: shape
        edge: root.edge
        length: root.contentLength + Appearance.sizes.padding * 2
        depth: root.depth
    }

    // Clip region = drawer body (excluding fillets); content is pinned to the
    // outer side so it slides in with the drawer.
    Item {
        id: bodyItem
        clip: true
        x: root.horizontal ? root.r : 0
        y: root.horizontal ? 0 : root.r
        width: root.horizontal ? shape.width - 2 * root.r : root.depth
        height: root.horizontal ? root.depth : shape.height - 2 * root.r

        Item {
            id: holder
            x: root.edge === "right" ? Appearance.sizes.padding
             : root.edge === "left" ? parent.width - Appearance.sizes.padding - root.contentDepth
             : Appearance.sizes.padding
            y: root.edge === "bottom" ? Appearance.sizes.padding
             : root.edge === "top" ? parent.height - Appearance.sizes.padding - root.contentDepth
             : Appearance.sizes.padding
            width: childrenRect.width
            height: childrenRect.height
        }
    }
}
