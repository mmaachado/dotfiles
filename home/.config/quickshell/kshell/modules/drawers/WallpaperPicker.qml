import QtQuick
import Quickshell
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

            Carousel {
                id: view
                anchors.fill: parent
                visible: count > 0
                model: root.shown

                delegate: CarouselCard {
                    id: card
                    required property string modelData
                    checked: modelData === Wallpapers.current
                    onActivated: root.apply(modelData)

                    Image {
                        anchors.fill: parent
                        source: Wallpapers.url(card.modelData)
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: true
                        sourceSize.width: 480
                    }
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
