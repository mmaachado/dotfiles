import QtQuick
import Quickshell
import qs.config

// A VSCode-style context menu: text rows without icons, shortcuts dimmed on
// the right, thin separators, and the accent behind the row under the mouse.
//
// Fill it with plain entries:
//     { text, shortcut, enabled, checked, separator, submenu: [entries], action: () => ... }
// or set `menu` to a D-Bus menu handle (a tray icon's `menu`), which is read
// through QsMenuOpener. Open it with popup(item, x, y); picking an entry
// runs it and closes the whole chain of submenus.
PopupWindow {
    id: root

    property var items: []
    property QsMenuHandle menu: null
    // The menu this one is a submenu of, if any.
    property var parentMenu: null

    readonly property var entries: root.tidy(root.menu ? opener.children.values.map(root.fromDbus) : root.items)
    property int current: -1

    readonly property int pad: 4
    readonly property int textInset: 16
    readonly property real widest: {
        let w = 0;
        for (let i = 0; i < rows.count; i++) {
            const row = rows.itemAt(i);
            if (row)
                w = Math.max(w, row.implicitWidth);
        }
        return w;
    }

    // Open with the menu's top-left corner at (x, y) in `item`.
    function popup(item: Item, x: real, y: real): void {
        root.place(item, x, y, 1, 1, Edges.Top | Edges.Left, Edges.Bottom | Edges.Right);
    }

    // Open beside `item`, on the far side from the screen edge it sits on
    // (the bar's edge unless given), `gap` px away.
    function popupFrom(item: Item, edge: string, gap: real): void {
        edge = edge || Appearance.barPosition;
        const g = gap > 0 ? gap : 12; // an omitted real arrives as NaN
        const across = edge === "left" || edge === "right";
        root.place(item,
            edge === "right" ? -g : 0, edge === "bottom" ? -g : 0,
            item.width + (across ? g : 0), item.height + (across ? 0 : g),
            {left: Edges.Right, right: Edges.Left, top: Edges.Bottom, bottom: Edges.Top}[edge] | (across ? Edges.Top : Edges.Left),
            {left: Edges.Right, right: Edges.Left, top: Edges.Bottom, bottom: Edges.Top}[edge] | (across ? Edges.Bottom : Edges.Right));
    }

    function place(item: Item, x: real, y: real, w: real, h: real, edges: int, gravity: int): void {
        anchor.item = item;
        anchor.rect.x = Math.round(x);
        anchor.rect.y = Math.round(y);
        anchor.rect.width = Math.round(w);
        anchor.rect.height = Math.round(h);
        anchor.edges = edges;
        anchor.gravity = gravity;
        root.current = -1;
        if (root.entries.length > 0) {
            root.show();
        } else {
            root.pending = true;
            waitEntries.restart();
        }
    }

    function show(): void {
        root.pending = false;
        waitEntries.stop();
        if (root.entries.length > 0)
            root.visible = true;
    }

    // Close this menu and every menu above it.
    function dismiss(): void {
        root.visible = false;
        if (root.parentMenu)
            root.parentMenu.dismiss();
    }

    function run(entry: var): void {
        if (!entry || entry.separator || entry.enabled === false || entry.submenu)
            return;
        root.dismiss();
        entry.action?.();
    }

    // dbusmenu labels mark mnemonics with "_" ("__" is a literal one).
    function fromDbus(e: var): var {
        return {
            text: (e.text ?? "").replace(/_(.)/g, "$1"),
            separator: e.isSeparator,
            enabled: e.enabled,
            checked: e.buttonType !== QsMenuButtonType.None && e.checkState === Qt.Checked,
            submenu: e.hasChildren ? e : null,
            action: () => e.triggered()
        };
    }

    // No separators at the ends or two in a row (apps' menus often have them).
    function tidy(list: var): var {
        const out = [];
        for (const e of list)
            if (!e.separator || (out.length > 0 && !out[out.length - 1].separator))
                out.push(e);
        while (out.length > 0 && out[out.length - 1].separator)
            out.pop();
        return out;
    }

    function step(delta: int): void {
        const n = root.entries.length;
        for (let i = 1; i <= n; i++) {
            const j = ((root.current < 0 && delta < 0 ? 0 : root.current) + delta * i + n) % n;
            const e = root.entries[j];
            if (!e.separator && e.enabled !== false) {
                root.current = j;
                return;
            }
        }
    }

    function openSubmenu(index: int): void {
        const e = root.entries[index];
        const row = rows.itemAt(index);
        if (!e?.submenu || !row) {
            sub.active = false;
            return;
        }
        sub.active = true;
        const m = sub.item;
        m.parentMenu = root;
        if (Array.isArray(e.submenu)) {
            m.menu = null;
            m.items = e.submenu;
        } else {
            m.items = [];
            m.menu = e.submenu;
        }
        m.popup(row, row.width + root.pad, -root.pad);
    }

    implicitWidth: Math.max(220, root.widest + root.pad * 2)
    implicitHeight: column.implicitHeight + root.pad * 2
    color: "transparent"
    grabFocus: true
    visible: false

    onVisibleChanged: if (!visible) sub.active = false
    // A D-Bus menu's entries arrive after it's asked for, and a popup that
    // grows once shown isn't repainted, so wait for them (briefly).
    property bool pending: false
    onEntriesChanged: if (pending && entries.length > 0) Qt.callLater(root.show)

    QsMenuOpener {
        id: opener
        menu: root.menu
    }

    Timer {
        id: waitEntries
        interval: 500
        onTriggered: root.show()
    }

    // Submenus open after a short hover, as in VSCode.
    Timer {
        id: hoverOpen
        interval: 200
        onTriggered: root.openSubmenu(root.current)
    }

    Loader {
        id: sub
        active: false
        source: "ContextMenu.qml"
    }

    Rectangle {
        anchors.fill: parent
        radius: 8
        color: Appearance.colors.surfaceLow
        border.width: 1
        border.color: Appearance.colors.outline

        focus: true
        Keys.onPressed: event => {
            const e = root.entries[root.current];
            if (event.key === Qt.Key_Down)
                root.step(1);
            else if (event.key === Qt.Key_Up)
                root.step(-1);
            else if (event.key === Qt.Key_Escape || (event.key === Qt.Key_Left && root.parentMenu))
                root.visible = false;
            else if (event.key === Qt.Key_Right && e?.submenu)
                root.openSubmenu(root.current);
            else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                e?.submenu ? root.openSubmenu(root.current) : root.run(e);
            else
                return;
            event.accepted = true;
        }

        Column {
            id: column
            x: root.pad
            y: root.pad
            width: parent.width - root.pad * 2

            Repeater {
                id: rows
                model: root.entries

                Item {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property bool usable: !modelData.separator && modelData.enabled !== false
                    readonly property bool lit: usable && root.current === index

                    width: column.width
                    height: modelData.separator ? 9 : label.implicitHeight + 14
                    implicitWidth: modelData.separator ? 0
                        : root.textInset * 2 + label.implicitWidth
                          + (keys.text ? 40 + keys.implicitWidth : 0)
                          + (modelData.submenu ? 20 : 0)

                    // Separators run the full width of the menu.
                    Rectangle {
                        visible: row.modelData.separator === true
                        x: -root.pad
                        width: row.width + root.pad * 2
                        height: 1
                        anchors.verticalCenter: parent.verticalCenter
                        color: Appearance.colors.outline
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: 4
                        visible: row.lit
                        color: Appearance.colors.primary
                    }

                    Icon {
                        visible: row.modelData.checked === true
                        x: (root.textInset - size) / 2
                        anchors.verticalCenter: parent.verticalCenter
                        name: "checkmark-symbolic"
                        size: 12
                        color: label.color
                    }

                    StyledText {
                        id: label
                        visible: !row.modelData.separator
                        x: root.textInset
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.text ?? ""
                        color: !row.usable ? Appearance.colors.textFaint
                            : row.lit ? Appearance.colors.onPrimary : Appearance.colors.text
                    }

                    StyledText {
                        id: keys
                        visible: !row.modelData.separator && text !== ""
                        anchors.right: parent.right
                        anchors.rightMargin: root.textInset
                        anchors.verticalCenter: parent.verticalCenter
                        text: row.modelData.shortcut ?? ""
                        color: row.lit ? Qt.alpha(Appearance.colors.onPrimary, 0.8) : Appearance.colors.textFaint
                    }

                    Icon {
                        visible: !!row.modelData.submenu
                        anchors.right: parent.right
                        anchors.rightMargin: 6
                        anchors.verticalCenter: parent.verticalCenter
                        name: "go-next-symbolic"
                        size: 12
                        color: label.color
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: row.usable
                        onEntered: {
                            root.current = row.index;
                            hoverOpen.restart();
                        }
                        onClicked: row.modelData.submenu ? root.openSubmenu(row.index) : root.run(row.modelData)
                    }
                }
            }
        }
    }
}
