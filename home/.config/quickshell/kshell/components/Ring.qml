import QtQuick
import QtQuick.Shapes
import qs.config

// Circular gauge: a track with an arc for `value` (0..1) and a label inside.
Item {
    id: root

    property real value: 0
    property string text: ""
    property string caption: ""
    property color color: value > 0.85 ? Appearance.colors.error : Appearance.colors.primary
    readonly property real stroke: 5

    implicitWidth: 56
    implicitHeight: 56 + (caption ? 18 : 0)

    Spring {
        id: shown
        target: Math.max(0, Math.min(1, root.value))
        preset: Appearance.spring.slowEffects
    }

    Item {
        id: dial
        width: root.width
        height: width

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Appearance.colors.secondaryContainer
                strokeWidth: root.stroke
                fillColor: "transparent"
                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - root.stroke / 2
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 360
                }
            }
            ShapePath {
                strokeColor: root.color
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap
                PathAngleArc {
                    centerX: dial.width / 2
                    centerY: dial.height / 2
                    radiusX: dial.width / 2 - root.stroke / 2
                    radiusY: radiusX
                    startAngle: -90
                    sweepAngle: 360 * shown.value
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            text: root.text
            font.pointSize: Appearance.font.small
            font.bold: true
        }
    }

    StyledText {
        visible: root.caption !== ""
        anchors.top: dial.bottom
        anchors.topMargin: 3
        anchors.horizontalCenter: dial.horizontalCenter
        text: root.caption
        color: Appearance.colors.textDim
        font.pointSize: Appearance.font.small
    }
}
