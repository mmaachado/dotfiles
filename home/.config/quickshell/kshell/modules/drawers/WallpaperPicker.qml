import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// Wallpaper carousel. ←/→ (or scroll) to browse, type to filter, Enter or a
// click on the centred image to apply, Esc to close.
Item {
    id: root

    property bool open
    readonly property list<string> shown: Wallpapers.files.filter(
        f => Wallpapers.name(f).toLowerCase().includes(input.text.trim().toLowerCase()))
    readonly property string selected: shown[view.currentIndex] ?? ""

    implicitWidth: 1120
    implicitHeight: content.implicitHeight

    onOpenChanged: {
        if (open) {
            input.text = "";
            Wallpapers.refresh();
            centreOnCurrent();
            input.forceActiveFocus();
        }
    }

    function centreOnCurrent(): void {
        const i = shown.indexOf(Wallpapers.current);
        view.positionViewAtIndex(Math.max(0, i), PathView.Center);
        view.currentIndex = Math.max(0, i);
    }

    function apply(path: string): void {
        if (!path)
            return;
        Wallpapers.apply(path);
        Visibilities.closeAll();
    }

    Connections {
        target: Wallpapers
        function onFilesChanged(): void { root.centreOnCurrent(); }
    }

    Column {
        id: content
        width: parent.width
        spacing: 14

        Item {
            width: parent.width
            height: 230

            PathView {
                id: view
                anchors.fill: parent
                visible: count > 0
                model: root.shown
                pathItemCount: Math.min(7, count)
                preferredHighlightBegin: 0.5
                preferredHighlightEnd: 0.5
                highlightRangeMode: PathView.StrictlyEnforceRange
                highlightMoveDuration: Appearance.anim.normal
                snapMode: PathView.SnapToItem

                path: Path {
                    startX: 0
                    startY: view.height / 2
                    PathAttribute { name: "itemScale"; value: 0.68 }
                    PathAttribute { name: "itemZ"; value: 0 }
                    PathAttribute { name: "itemOpacity"; value: 0.45 }
                    PathLine { x: view.width / 2; y: view.height / 2 }
                    PathAttribute { name: "itemScale"; value: 1 }
                    PathAttribute { name: "itemZ"; value: 10 }
                    PathAttribute { name: "itemOpacity"; value: 1 }
                    PathLine { x: view.width; y: view.height / 2 }
                    PathAttribute { name: "itemScale"; value: 0.68 }
                    PathAttribute { name: "itemZ"; value: 0 }
                    PathAttribute { name: "itemOpacity"; value: 0.45 }
                }

                delegate: Item {
                    id: card
                    required property string modelData
                    required property int index
                    readonly property bool centred: PathView.isCurrentItem
                    readonly property bool applied: modelData === Wallpapers.current

                    width: 320
                    height: 200
                    z: PathView.itemZ ?? 0
                    scale: PathView.itemScale ?? 1
                    opacity: PathView.itemOpacity ?? 1

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Appearance.sizes.radius
                        color: Appearance.colors.surfaceHigh

                        Image {
                            anchors.fill: parent
                            source: Wallpapers.url(card.modelData)
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            cache: true
                            sourceSize.width: 480
                        }
                    }

                    // Focus ring on the centred card (keyboard position).
                    Rectangle {
                        anchors.fill: parent
                        anchors.margins: -4
                        radius: Appearance.sizes.radius + 4
                        color: "transparent"
                        border.width: 3
                        border.color: Appearance.colors.primary
                        visible: card.centred
                    }

                    Rectangle {
                        visible: card.applied
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
                        onClicked: card.centred ? root.apply(card.modelData) : (view.currentIndex = card.index)
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: event => (event.angleDelta.y || event.angleDelta.x) > 0
                        ? view.decrementCurrentIndex() : view.incrementCurrentIndex()
                }
            }

            // Empty state
            Column {
                anchors.centerIn: parent
                spacing: 12
                visible: view.count === 0 && Wallpapers.scanned

                Icon {
                    anchors.horizontalCenter: parent.horizontalCenter
                    name: "preferences-desktop-wallpaper-symbolic"
                    size: 48
                    color: Appearance.colors.textFaint
                }
                StyledText {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: Wallpapers.files.length === 0 ? "Add images to ~/Pictures/Wallpapers" : "No wallpapers match"
                    color: Appearance.colors.textDim
                }
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: Wallpapers.files.length === 0
                    width: openLabel.implicitWidth + 32
                    height: 36
                    radius: height / 2
                    color: Appearance.colors.primaryContainer

                    StyledText {
                        id: openLabel
                        anchors.centerIn: parent
                        text: "Open folder"
                    }
                    StateLayer {
                        onClicked: {
                            Wallpapers.openFolder();
                            Visibilities.closeAll();
                        }
                    }
                }
            }
        }

        StyledText {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: root.selected ? Wallpapers.name(root.selected) : " "
            font.pointSize: Appearance.font.large
            font.bold: true
        }

        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 420
            height: 44
            radius: height / 2
            color: Appearance.colors.surfaceHigh

            Icon {
                id: searchIcon
                anchors.left: parent.left
                anchors.leftMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                name: "search-symbolic"
                size: 16
                color: Appearance.colors.textDim
            }

            TextInput {
                id: input
                anchors.left: searchIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                color: Appearance.colors.text
                selectionColor: Appearance.colors.primary
                selectedTextColor: Appearance.colors.onPrimary
                font.family: Appearance.font.family
                font.pointSize: Appearance.font.normal
                clip: true

                onTextChanged: view.currentIndex = 0

                Keys.onLeftPressed: view.decrementCurrentIndex()
                Keys.onRightPressed: view.incrementCurrentIndex()
                Keys.onReturnPressed: root.apply(root.selected)
                Keys.onEnterPressed: root.apply(root.selected)
                Keys.onEscapePressed: Visibilities.closeAll()

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: input.text === ""
                    text: `Filter ${Wallpapers.files.length} wallpapers…   ← → to browse, Enter to apply`
                    color: Appearance.colors.textFaint
                }
            }
        }
    }
}
