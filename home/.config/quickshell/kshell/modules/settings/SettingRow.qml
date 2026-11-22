import QtQuick
import qs.components
import qs.config

// A labelled row with an optional description and controls on the right.
Rectangle {
    id: row
    property string label
    property string description
    property string icon
    default property alias control: slot.data

    width: parent?.width ?? 0
    implicitHeight: Math.max(64, text.implicitHeight + 28)
    radius: Appearance.sizes.radius
    color: Appearance.colors.surface

    Icon {
        id: rowIcon
        visible: row.icon !== ""
        anchors.left: parent.left
        anchors.leftMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        name: row.icon
        size: 24
    }

    Column {
        id: text
        anchors.left: rowIcon.visible ? rowIcon.right : parent.left
        anchors.leftMargin: 16
        anchors.right: slot.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2

        StyledText {
            width: parent.width
            text: row.label
            font.pointSize: Appearance.font.normal + 0.5
        }
        StyledText {
            width: parent.width
            visible: text !== ""
            text: row.description
            color: Appearance.colors.textDim
            font.pointSize: Appearance.font.small
            wrapMode: Text.WordWrap
            elide: Text.ElideNone
        }
    }

    Row {
        id: slot
        anchors.right: parent.right
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
    }
}
