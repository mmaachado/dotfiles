import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Wallpaper carousel. ←/→ (or scroll) to browse, type to filter, Enter or a
// click on the centred image to apply, Esc to close. The highlighted wallpaper
// is previewed on the desktop once you stop on it.
Item {
    id: root

    property bool open
    readonly property list<string> shown: Wallpapers.files.filter(
        f => Wallpapers.name(f).toLowerCase().includes(input.text.trim().toLowerCase()))
    readonly property string selected: shown[view.currentIndex] ?? ""

    // Narrower on portrait screens (ScreenShell sets the room there is).
    property real maxWidth: Infinity
    implicitWidth: Math.min(1120, maxWidth)
    implicitHeight: content.implicitHeight

    onOpenChanged: {
        if (open) {
            input.text = "";
            Wallpapers.refresh();
            centreOnCurrent();
            input.forceActiveFocus();
        } else {
            previewDelay.stop();
            Wallpapers.preview = "";
            input.focus = false; // see Launcher.qml
        }
    }

    onSelectedChanged: if (open) previewDelay.restart()

    // Only preview where browsing stops, not every wallpaper scrolled past.
    Timer {
        id: previewDelay
        interval: 350
        onTriggered: Wallpapers.setPreview(root.selected, Visibilities.screen)
    }

    function centreOnCurrent(): void {
        const i = shown.indexOf(Wallpapers.currentOn(Visibilities.screen));
        view.positionViewAtIndex(Math.max(0, i), PathView.Center);
        view.currentIndex = Math.max(0, i);
    }

    function apply(path: string): void {
        if (!path)
            return;
        Wallpapers.apply(path, Visibilities.screen);
        Visibilities.closeAll();
    }

    // "This display | All displays" choice, with more than one screen.
    component ModeChip: Rectangle {
        id: chip
        property string mode
        property string label
        readonly property bool on: Settings.options.wallpaperMode === mode

        width: chipLabel.implicitWidth + 28
        height: 30
        radius: height / 2
        color: on ? Appearance.colors.primary : Appearance.colors.surfaceHigh

        StyledText {
            id: chipLabel
            anchors.centerIn: parent
            text: chip.label
            font.pointSize: Appearance.font.small
            color: chip.on ? Appearance.colors.onPrimary : Appearance.colors.text
        }
        StateLayer {
            tint: chip.on ? Appearance.colors.onPrimary : Appearance.colors.text
            onClicked: {
                Settings.options.wallpaperMode = chip.mode;
                // Re-preview where the highlighted wallpaper now goes.
                if (root.selected)
                    Wallpapers.setPreview(root.selected, Visibilities.screen);
            }
        }
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
                    checked: modelData === Wallpapers.currentOn(Visibilities.screen)
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

        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: Quickshell.screens.length > 1
            spacing: 6

            ModeChip {
                mode: "per-display"
                label: "This display"
            }
            ModeChip {
                mode: "same"
                label: "All displays"
            }
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
