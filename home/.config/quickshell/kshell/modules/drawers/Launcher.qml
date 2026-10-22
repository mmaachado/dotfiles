import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// App launcher. Type to search, ↑/↓ to select, Enter to launch,
// Tab to hand the query over to KRunner, Esc to close. Right-click an app
// to pin/unpin it in the bar.
Item {
    id: root

    property bool open
    readonly property int rowHeight: 54
    readonly property int maxRows: 8
    property list<DesktopEntry> results: Apps.query(input.text)

    implicitWidth: 620
    implicitHeight: list.height + search.height + 10

    onOpenChanged: {
        if (open) {
            input.text = "";
            list.currentIndex = 0;
            input.forceActiveFocus();
        }
    }

    function launch(app: DesktopEntry): void {
        if (!app)
            return;
        Apps.launch(app);
        Visibilities.closeAll();
    }

    ListView {
        id: list
        width: parent.width
        height: Math.max(1, Math.min(count, root.maxRows)) * root.rowHeight
        clip: true
        model: root.results
        verticalLayoutDirection: ListView.BottomToTop
        highlightMoveDuration: Appearance.anim.fast
        highlight: Rectangle {
            radius: Appearance.sizes.radius
            color: Appearance.colors.primaryContainer
        }

        Behavior on height {
            NumberAnimation { duration: Appearance.anim.normal; easing.type: Easing.OutCubic }
        }

        delegate: Item {
            id: row
            required property DesktopEntry modelData
            required property int index

            width: list.width
            height: root.rowHeight

            Icon {
                id: appIcon
                anchors.left: parent.left
                anchors.leftMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                name: row.modelData.icon
                size: 34
            }

            Column {
                anchors.left: appIcon.right
                anchors.leftMargin: 14
                anchors.right: pin.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: row.modelData.name
                    font.pointSize: Appearance.font.large
                }
                StyledText {
                    width: parent.width
                    text: row.modelData.comment || row.modelData.genericName
                    visible: text !== ""
                    color: Appearance.colors.textDim
                    font.pointSize: Appearance.font.small
                }
            }

            Icon {
                id: pin
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                name: "view-pin-symbolic"
                size: 16
                color: Appearance.colors.primary
                visible: Dock.isPinned(row.modelData.id)
            }

            StateLayer {
                radius: Appearance.sizes.radius
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        Dock.togglePin(row.modelData.id);
                    else
                        root.launch(row.modelData);
                }
                onContainsMouseChanged: if (containsMouse) list.currentIndex = row.index
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: "No apps found — press Tab to search with KRunner"
            color: Appearance.colors.textDim
        }
    }

    Rectangle {
        id: search
        anchors.top: list.bottom
        anchors.topMargin: 10
        width: parent.width
        height: 48
        radius: height / 2
        color: Appearance.colors.surfaceHigh

        Icon {
            id: searchIcon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: "search-symbolic"
            size: 18
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
            font.pointSize: Appearance.font.large
            clip: true

            onTextChanged: list.currentIndex = 0

            Keys.onUpPressed: list.incrementCurrentIndex()
            Keys.onDownPressed: list.decrementCurrentIndex()
            Keys.onReturnPressed: root.launch(root.results[list.currentIndex])
            Keys.onEnterPressed: root.launch(root.results[list.currentIndex])
            Keys.onEscapePressed: Visibilities.closeAll()
            Keys.onTabPressed: {
                Quickshell.execDetached(["qdbus6", "org.kde.krunner", "/App", "org.kde.krunner.App.query", text]);
                Visibilities.closeAll();
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: `Search ${Apps.all.length} apps…   right-click to pin`
                color: Appearance.colors.textFaint
                font.pointSize: Appearance.font.large
            }
        }
    }
}
