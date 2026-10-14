import QtQuick
import qs.config

// Rounded container used to group bar modules.
Rectangle {
    default property alias content: col.data
    property alias spacing: col.spacing
    property int padding: 6

    implicitWidth: Appearance.sizes.barWidth - 12
    implicitHeight: col.implicitHeight + padding * 2
    radius: width / 2
    color: Appearance.colors.surface

    Column {
        id: col
        anchors.centerIn: parent
        spacing: 4
    }
}
