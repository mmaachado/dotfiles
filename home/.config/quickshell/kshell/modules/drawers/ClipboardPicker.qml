import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Clipboard history (Meta+V). Type to filter, ↑/↓ to select, Enter or a click
// to copy it back, Delete to forget it, right-click to pin, Esc to close.
Item {
    id: root

    property bool open
    readonly property int rowHeight: 58
    readonly property int maxRows: 7
    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        const h = Clipboard.history.filter(e => !q || e.text.toLowerCase().includes(q));
        // Pinned first, otherwise newest first.
        return h.filter(e => e.pinned).concat(h.filter(e => !e.pinned));
    }

    implicitWidth: 620
    implicitHeight: list.height + search.height + 10

    onOpenChanged: {
        if (open) {
            input.text = "";
            list.currentIndex = 0;
            input.forceActiveFocus();
        } else {
            // Don't keep keyboard focus while hidden: Qt crashes tearing down
            // a focused text input when the shell exits.
            input.focus = false;
        }
    }

    function pick(entry: var): void {
        if (!entry)
            return;
        Clipboard.copy(entry.id);
        Visibilities.closeAll();
    }

    function ago(t: int): string {
        const s = Math.max(0, Math.floor(Time.now.getTime() / 1000) - t);
        return s < 60 ? "just now" : s < 3600 ? `${Math.floor(s / 60)} min ago`
            : s < 86400 ? `${Math.floor(s / 3600)} h ago` : `${Math.floor(s / 86400)} d ago`;
    }

    ListView {
        id: list
        width: parent.width
        height: Math.max(1, Math.min(count, root.maxRows)) * root.rowHeight
        clip: true
        model: ScriptModel {
            values: root.results
            objectProp: "id"
        }
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
            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem // see Launcher.qml
            readonly property color ink: current ? Appearance.colors.onPrimaryContainer : Appearance.colors.text

            width: list.width
            height: root.rowHeight

            Icon {
                id: kindIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: /^https?:\/\//.test(row.modelData.text.trim()) ? "link-symbolic" : "edit-paste-symbolic"
                size: 20
                color: Qt.alpha(row.ink, 0.7)
            }

            Column {
                anchors.left: kindIcon.right
                anchors.leftMargin: 14
                anchors.right: pinIcon.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    // One line: collapse whitespace so multi-line copies still read.
                    text: row.modelData.text.replace(/\s+/g, " ").trim()
                    color: row.ink
                    maximumLineCount: 1
                }
                StyledText {
                    width: parent.width
                    readonly property int lines: row.modelData.text.split("\n").length
                    text: root.ago(row.modelData.time) + (lines > 1 ? ` · ${lines} lines` : "")
                        + ` · ${row.modelData.text.length} chars`
                    color: Qt.alpha(row.ink, 0.7)
                    font.pointSize: Appearance.font.small
                }
            }

            Icon {
                id: pinIcon
                anchors.right: parent.right
                anchors.rightMargin: 16
                anchors.verticalCenter: parent.verticalCenter
                name: "view-pin-symbolic"
                size: 16
                color: Appearance.colors.primary
                visible: row.modelData.pinned
            }

            StateLayer {
                radius: Appearance.sizes.radius
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    if (mouse.button === Qt.RightButton)
                        Clipboard.pin(row.modelData.id);
                    else if (mouse.button === Qt.MiddleButton)
                        Clipboard.remove(row.modelData.id);
                    else
                        root.pick(row.modelData);
                }
                onContainsMouseChanged: if (containsMouse) list.currentIndex = row.index
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: Clipboard.history.length ? "Nothing matches" : "Nothing copied yet"
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
            name: "edit-paste-symbolic"
            size: 18
            color: Appearance.colors.textDim
        }

        TextInput {
            id: input
            anchors.left: searchIcon.right
            anchors.leftMargin: 12
            anchors.right: clearAll.left
            anchors.rightMargin: 12
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
            Keys.onReturnPressed: root.pick(root.results[list.currentIndex])
            Keys.onEnterPressed: root.pick(root.results[list.currentIndex])
            Keys.onEscapePressed: Visibilities.closeAll()
            Keys.onDeletePressed: event => {
                // Delete forgets the selected entry once the search is empty
                // (otherwise it edits the search as usual).
                const e = root.results[list.currentIndex];
                if (input.text === "" && e)
                    Clipboard.remove(e.id);
                else
                    event.accepted = false;
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: `Search ${Clipboard.history.length} copies…   right-click to pin, Delete to forget`
                color: Appearance.colors.textFaint
                font.pointSize: Appearance.font.large
            }
        }

        IconButton {
            id: clearAll
            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            icon: "edit-clear-history-symbolic"
            iconSize: 16
            tooltip: "Clear (keeps pinned)"
            onClicked: Clipboard.clear()
        }
    }
}
