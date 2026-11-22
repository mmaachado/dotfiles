import QtQuick
import qs.config

// Rounded container used to group bar modules. Stacks its content along
// the bar: a column in a vertical bar, a row in a horizontal one.
Rectangle {
    id: root

    default property alias content: grid.data
    property alias spacing: grid.spacing
    property int padding: 6
    readonly property bool vertical: Appearance.barVertical
    // The grid holding the content, for overlays that track its children.
    readonly property Item column: grid

    implicitWidth: vertical ? Appearance.sizes.barWidth - 12 : grid.implicitWidth + padding * 2
    implicitHeight: vertical ? grid.implicitHeight + padding * 2 : Appearance.sizes.barWidth - 12
    radius: Math.min(width, height) / 2
    color: Appearance.colors.surface

    Grid {
        id: grid
        z: 1 // above overlays added to the pill itself
        anchors.centerIn: parent
        spacing: 4
        // One column, or one row (99 is "as many as there are").
        columns: root.vertical ? 1 : 99
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter
    }
}
