import QtQuick
import QtQuick.Effects
import qs.components
import qs.config
import qs.services

// Theme carousel. ←/→ (or scroll) to browse, Enter or a click on the centred
// card to apply, Esc to close. Each card previews the theme over the current
// wallpaper: a mock window and shell bar in the theme's colours.
FocusScope {
    id: root

    property bool open
    readonly property var selected: Themes.list[view.currentIndex] ?? null

    implicitWidth: 1000
    implicitHeight: content.implicitHeight

    onOpenChanged: {
        if (open) {
            const i = Themes.list.findIndex(t => t.id === Themes.current);
            view.positionViewAtIndex(Math.max(0, i), PathView.Center);
            view.currentIndex = Math.max(0, i);
            root.forceActiveFocus();
        }
    }

    function apply(theme: var): void {
        if (!theme)
            return;
        Themes.apply(theme.id);
        Visibilities.closeAll();
    }

    Keys.onLeftPressed: view.decrementCurrentIndex()
    Keys.onRightPressed: view.incrementCurrentIndex()
    Keys.onReturnPressed: apply(selected)
    Keys.onEnterPressed: apply(selected)
    Keys.onSpacePressed: apply(selected)
    Keys.onEscapePressed: Visibilities.closeAll()

    Column {
        id: content
        width: parent.width
        spacing: 14

        Carousel {
            id: view
            width: parent.width
            height: 230
            visibleCards: 5
            model: Themes.list

            delegate: CarouselCard {
                id: card
                required property var modelData
                readonly property var p: modelData.palette
                readonly property color window: Themes.rgb(p.window)
                readonly property color view: Themes.rgb(p.view)
                readonly property color header: Themes.rgb(p.header)
                readonly property color text: Themes.rgb(p.text)
                readonly property color accent: Themes.rgb(p.accent)
                readonly property real glass: modelData.blur ? 0.62 : 1

                checked: modelData.id === Themes.current
                onActivated: root.apply(modelData)

                // Wallpaper, blurred for blur themes
                Image {
                    id: wall
                    anchors.fill: parent
                    source: Wallpapers.current ? Wallpapers.url(Wallpapers.current) : ""
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    sourceSize.width: 480
                    visible: !card.modelData.blur
                }
                MultiEffect {
                    anchors.fill: parent
                    source: wall
                    visible: card.modelData.blur
                    blurEnabled: true
                    blur: 1
                    blurMax: 40
                    autoPaddingEnabled: false
                }

                // Shell bar
                Rectangle {
                    width: 22
                    height: parent.height
                    color: Qt.alpha(card.window, card.glass)

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 14
                        spacing: 6
                        Rectangle { width: 10; height: 18; radius: 5; color: card.accent }
                        Repeater {
                            model: 4
                            Rectangle { width: 10; height: 10; radius: 3; color: Qt.alpha(card.text, 0.35) }
                        }
                    }
                }

                // Mock window
                Rectangle {
                    x: 46
                    y: 30
                    width: parent.width - 70
                    height: parent.height - 52
                    radius: 10
                    color: Qt.alpha(card.view, card.glass)
                    clip: true

                    Rectangle {
                        width: parent.width
                        height: 22
                        color: Qt.alpha(card.header, card.glass)

                        Row {
                            x: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 5
                            Repeater {
                                model: ["#ff5f57", "#febc2e", "#28c840"]
                                Rectangle { required property string modelData; width: 8; height: 8; radius: 4; color: modelData }
                            }
                        }
                    }

                    Column {
                        x: 14
                        y: 36
                        spacing: 8
                        Rectangle { width: 120; height: 8; radius: 4; color: Qt.alpha(card.text, 0.85) }
                        Rectangle { width: 170; height: 6; radius: 3; color: Qt.alpha(card.text, 0.4) }
                        Rectangle { width: 150; height: 6; radius: 3; color: Qt.alpha(card.text, 0.4) }
                        Rectangle { width: 64; height: 18; radius: 9; color: card.accent }
                    }
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2

            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.selected?.name ?? ""
                font.pointSize: Appearance.font.large
                font.bold: true
            }
            StyledText {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "← → to browse · Enter to apply · Esc to close"
                color: Appearance.colors.textFaint
                font.pointSize: Appearance.font.small
            }
        }
    }
}
