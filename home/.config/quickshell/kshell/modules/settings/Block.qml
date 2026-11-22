import QtQuick
import qs.components
import qs.config

// Like SettingRow, but its controls flow underneath the label (for
// choices that need more room than the right-hand side of a row).
Rectangle {
    id: block
    property string label
    property string description
    default property alias body: flow.data

    width: parent?.width ?? 0
    implicitHeight: col.implicitHeight + 32
    radius: Appearance.sizes.radius
    color: Appearance.colors.surface

    Column {
        id: col
        x: 16
        y: 16
        width: parent.width - 32
        spacing: 2

        StyledText {
            width: parent.width
            text: block.label
            font.pointSize: Appearance.font.normal + 0.5
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            text: block.description
            color: Appearance.colors.textDim
            font.pointSize: Appearance.font.small
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
        Item { width: 1; height: 10 }
        Flow {
            id: flow
            width: parent.width
            spacing: 8
        }
    }
}
