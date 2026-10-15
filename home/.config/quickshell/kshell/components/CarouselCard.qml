import QtQuick
import Quickshell.Widgets
import qs.config

// Delegate for Carousel. Children go inside a rounded, clipped card.
// Clicking a side card centres it; clicking the centred card emits activated().
Item {
    id: card

    required property int index
    readonly property bool centred: PathView.isCurrentItem
    property bool checked: false
    default property alias content: clip.data

    signal activated

    width: PathView.view.cardWidth
    height: PathView.view.cardHeight
    z: PathView.itemZ ?? 0
    scale: PathView.itemScale ?? 1
    opacity: PathView.itemOpacity ?? 1

    ClippingRectangle {
        id: clip
        anchors.fill: parent
        radius: Appearance.sizes.radius
        color: Appearance.colors.surfaceHigh
    }

    // Focus ring = keyboard position
    Rectangle {
        anchors.fill: parent
        anchors.margins: -4
        radius: Appearance.sizes.radius + 4
        color: "transparent"
        border.width: 3
        border.color: Appearance.colors.primary
        visible: card.centred
    }

    // Check badge = currently applied
    Rectangle {
        visible: card.checked
        anchors.top: parent.top
        anchors.right: parent.right
        anchors.margins: 10
        width: 28
        height: 28
        radius: 14
        color: Appearance.colors.primary

        Icon {
            anchors.centerIn: parent
            name: "checkmark-symbolic"
            size: 16
            color: Appearance.colors.onPrimary
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: card.centred ? card.activated() : (card.PathView.view.currentIndex = card.index)
    }
}
