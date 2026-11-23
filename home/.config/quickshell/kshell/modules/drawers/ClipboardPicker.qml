import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Clipboard history (Meta+V), laid out like Windows 11's: cards for every
// copy, text or image, with pinned ones on top. Type to search, ↑/↓ to
// move, Enter or a click to copy back, Ctrl+P to pin, Delete to forget,
// Esc to close. Each card has pin, send-to-phone (KDE Connect) and delete
// buttons; right-click one for the same actions in a menu.
Item {
    id: root

    property bool open
    readonly property int maxHeight: 520
    readonly property var results: {
        const q = input.text.trim().toLowerCase();
        // Images have no text to search; they show only when not searching.
        const h = Clipboard.history.filter(e => !q || (e.kind !== "image" && e.text.toLowerCase().includes(q)));
        return h.filter(e => e.pinned).concat(h.filter(e => !e.pinned));
    }

    implicitWidth: 560
    implicitHeight: header.height + search.height + list.height + 24

    onOpenChanged: {
        if (open) {
            input.text = "";
            list.currentIndex = 0;
            list.positionViewAtBeginning();
            input.forceActiveFocus();
        } else {
            // Don't keep keyboard focus while hidden: Qt crashes tearing down
            // a focused text input when the shell exits.
            input.focus = false;
        }
    }

    ContextMenu {
        id: menu
    }

    function showMenu(card: Item, e: var, x: real, y: real): void {
        const items = [
            { text: "Copy", shortcut: "Enter", action: () => root.pick(e) },
            { text: e.pinned ? "Unpin" : "Pin", shortcut: "Ctrl+P", action: () => Clipboard.pin(e.id) }
        ];
        if (KdeConnect.available)
            items.push({ text: "Send to Phone",
                         action: () => e.kind === "image" ? KdeConnect.shareFile(e.path) : KdeConnect.shareText(e.text) });
        items.push({ separator: true }, { text: "Delete", shortcut: "Delete", action: () => Clipboard.remove(e.id) });
        menu.items = items;
        menu.popup(card, x, y);
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

    function url(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    // ── Header ───────────────────────────────────────────────────────
    Item {
        id: header
        width: parent.width
        height: 36

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 4
            anchors.verticalCenter: parent.verticalCenter
            text: "Clipboard"
            font.pointSize: Appearance.font.large
            font.bold: true
        }

        Rectangle {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: Clipboard.history.some(e => !e.pinned)
            width: clearLabel.implicitWidth + 24
            height: 30
            radius: height / 2
            color: Appearance.colors.surfaceHigh

            StyledText {
                id: clearLabel
                anchors.centerIn: parent
                text: "Clear all"
                font.pointSize: Appearance.font.small
            }
            StateLayer {
                onClicked: Clipboard.clear()
            }
        }
    }

    // ── Search ───────────────────────────────────────────────────────
    Rectangle {
        id: search
        anchors.top: header.bottom
        anchors.topMargin: 8
        width: parent.width
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

            onTextChanged: list.currentIndex = 0

            Keys.onUpPressed: list.decrementCurrentIndex()
            Keys.onDownPressed: list.incrementCurrentIndex()
            Keys.onReturnPressed: root.pick(root.results[list.currentIndex])
            Keys.onEnterPressed: root.pick(root.results[list.currentIndex])
            Keys.onEscapePressed: Visibilities.closeAll()
            Keys.onPressed: event => {
                const e = root.results[list.currentIndex];
                if (event.key === Qt.Key_P && (event.modifiers & Qt.ControlModifier) && e) {
                    Clipboard.pin(e.id);
                    event.accepted = true;
                } else if (event.key === Qt.Key_Delete && input.text === "" && e) {
                    // Delete forgets the selected card once the search is
                    // empty (otherwise it edits the search as usual).
                    Clipboard.remove(e.id);
                    event.accepted = true;
                }
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: `Search ${Clipboard.history.length} copies…`
                color: Appearance.colors.textFaint
            }
        }
    }

    // ── Cards ────────────────────────────────────────────────────────
    ListView {
        id: list
        anchors.top: search.bottom
        anchors.topMargin: 12
        width: parent.width
        height: Math.max(80, Math.min(contentHeight, root.maxHeight))
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        highlightMoveDuration: Appearance.anim.fast
        model: ScriptModel {
            values: root.results
            objectProp: "id"
        }

        delegate: Item {
            id: slot
            required property var modelData
            required property int index
            readonly property bool current: ListView.isCurrentItem // see Launcher.qml
            // "Pinned" / "Recent" above the first card of each group, when
            // anything is pinned.
            readonly property bool anyPinned: root.results.length > 0 && root.results[0].pinned
            readonly property bool firstOfGroup: index === 0 || root.results[index - 1]?.pinned !== modelData.pinned
            readonly property string heading: anyPinned && firstOfGroup ? (modelData.pinned ? "Pinned" : "Recent") : ""

            width: list.width
            height: headingText.height + card.height

            StyledText {
                id: headingText
                width: parent.width
                height: slot.heading ? implicitHeight + 6 : 0
                visible: slot.heading !== ""
                leftPadding: 4
                text: slot.heading
                color: Appearance.colors.textDim
                font.pointSize: Appearance.font.small
                font.bold: true
            }

            Rectangle {
                id: card
                readonly property var modelData: slot.modelData
                readonly property int index: slot.index
                readonly property bool current: slot.current
                readonly property bool image: modelData.kind === "image"

                y: headingText.height
                width: list.width
                height: (image ? thumb.height + meta.height + 22 : textBox.height + meta.height + 26)
                radius: Appearance.sizes.radius
                color: current ? Appearance.colors.primaryContainer : Appearance.colors.surface
                border.width: current ? 0 : 1
                border.color: Qt.alpha(Appearance.colors.outline, 0.35)

                StateLayer {
                    radius: card.radius
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onClicked: mouse => {
                        if (mouse.button === Qt.RightButton)
                            root.showMenu(card, card.modelData, mouse.x, mouse.y);
                        else
                            root.pick(card.modelData);
                    }
                    onContainsMouseChanged: if (containsMouse) list.currentIndex = card.index
                }

                // Text: up to three lines.
                StyledText {
                    id: textBox
                    visible: !card.image
                    x: 14
                    y: 12
                    width: parent.width - 28 - actions.width
                    text: card.image ? "" : card.modelData.text.trim()
                    color: card.current ? Appearance.colors.onPrimaryContainer : Appearance.colors.text
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }

                // Image: a thumbnail.
                Rectangle {
                    id: thumb
                    visible: card.image
                    x: 12
                    y: 10
                    width: Math.min(parent.width - 24 - actions.width,
                        card.image ? 140 * (card.modelData.width ?? 1) / Math.max(1, card.modelData.height ?? 1) : 0)
                    height: card.image ? 140 : 0
                    radius: Appearance.sizes.radiusSmall
                    color: Appearance.colors.surfaceHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: card.image && card.modelData.path ? root.url(card.modelData.path) : ""
                        sourceSize.height: 280
                        fillMode: Image.PreserveAspectFit
                        asynchronous: true
                    }
                }

                StyledText {
                    id: meta
                    x: 14
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 8
                    readonly property int lines: card.image ? 0 : card.modelData.text.split("\n").length
                    text: root.ago(card.modelData.time)
                        + (card.image ? ` · ${card.modelData.width} × ${card.modelData.height}`
                            : (lines > 1 ? ` · ${lines} lines` : ""))
                    color: Qt.alpha(card.current ? Appearance.colors.onPrimaryContainer : Appearance.colors.text, 0.65)
                    font.pointSize: Appearance.font.small
                }

                // Pin and delete, top right; the pin stays visible when pinned.
                Row {
                    id: actions
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.margins: 6
                    spacing: 2

                    IconButton {
                        icon: "view-pin-symbolic"
                        iconSize: 15
                        active: card.modelData.pinned
                        opacity: card.modelData.pinned || card.current ? 1 : 0
                        tooltip: card.modelData.pinned ? "Unpin" : "Pin"
                        onClicked: Clipboard.pin(card.modelData.id)
                    }
                    IconButton {
                        // To every reachable phone paired in KDE Connect.
                        visible: KdeConnect.available
                        icon: "smartphone-symbolic"
                        iconSize: 15
                        opacity: card.current ? 1 : 0
                        tooltip: "Send to phone"
                        onClicked: {
                            if (card.image)
                                KdeConnect.shareFile(card.modelData.path);
                            else
                                KdeConnect.shareText(card.modelData.text);
                        }
                    }
                    IconButton {
                        icon: "edit-delete-symbolic"
                        iconSize: 15
                        opacity: card.current ? 1 : 0
                        tooltip: "Delete"
                        onClicked: Clipboard.remove(card.modelData.id)
                    }
                }
            }
        }

        StyledText {
            anchors.centerIn: parent
            visible: list.count === 0
            text: Clipboard.history.length ? "Nothing matches" : "Nothing copied yet"
            color: Appearance.colors.textDim
        }
    }
}
