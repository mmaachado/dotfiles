import QtQuick
import qs.config

// Rounded container used to group bar modules.
Rectangle {
    default property alias content: col.data
    property alias spacing: col.spacing
    property int padding: 6
    // The column holding the content, for overlays that track its children.
    readonly property Item column: col

    implicitWidth: Appearance.sizes.barWidth - 12
    implicitHeight: col.implicitHeight + padding * 2
    radius: width / 2
    color: Appearance.colors.surface

    Column {
        id: col
        z: 1 // above overlays added to the pill itself
        anchors.centerIn: parent
        spacing: 4
    }
}
