import QtQuick
import QtQuick.Shapes
import qs.config

// Background for a drawer that grows out of a frame edge, with concave fillets
// where it meets the frame (the Caelestia look). The item is `length + 2*r`
// along the edge; `depth` is how far it sticks out.
Shape {
    id: root

    property string edge: "top"   // top | bottom | left | right
    property real length: 0
    property real depth: 0
    property real r: Appearance.sizes.rounding
    property color color: Appearance.colors.frame

    readonly property bool horizontal: edge === "top" || edge === "bottom"
    readonly property real rr: Math.max(0, Math.min(r, depth / 2))

    width: horizontal ? length + 2 * r : depth
    height: horizontal ? depth : length + 2 * r
    preferredRendererType: Shape.CurveRenderer
    visible: depth > 0.5

    function path(): string {
        const r = root.r, rr = root.rr, d = root.depth, T = root.length + 2 * r;
        const fr = Math.min(r, d); // fillet radius
        // Path in "top edge" space: x along the edge, y = depth from the edge.
        const pts = [
            ["M", r - fr, 0],
            ["A", fr, 1, r, fr],
            ["L", r, d - rr],
            ["A", rr, 0, r + rr, d],
            ["L", T - r - rr, d],
            ["A", rr, 0, T - r, d - rr],
            ["L", T - r, fr],
            ["A", fr, 1, T - r + fr, 0],
        ];
        const map = {
            top: (x, y) => [x, y],
            bottom: (x, y) => [x, d - y],
            left: (x, y) => [y, x],
            right: (x, y) => [d - y, x],
        }[root.edge];
        const flip = root.edge === "bottom" || root.edge === "left";
        return pts.map(p => {
            if (p[0] === "A") {
                const [x, y] = map(p[3], p[4]);
                const sweep = flip ? 1 - p[2] : p[2];
                return `A ${p[1]} ${p[1]} 0 0 ${sweep} ${x} ${y}`;
            }
            const [x, y] = map(p[1], p[2]);
            return `${p[0]} ${x} ${y}`;
        }).join(" ") + " Z";
    }

    ShapePath {
        fillColor: root.color
        strokeWidth: -1
        PathSvg { path: root.path() }
    }
}
