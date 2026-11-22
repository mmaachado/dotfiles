import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Settings → Displays: arrangement, primary display, orientation, mode and
// scale of each output (through Displays / kscreen-doctor), plus where the
// bar, notch and popups go when there's more than one display.
Column {
    id: root

    // Output whose controls are shown below the arrangement.
    property string selected: ""
    readonly property var current: Displays.output(selected) ?? Displays.output(Displays.primary) ?? Displays.outputs[0] ?? null

    spacing: 10

    // ── Confirm risky changes ────────────────────────────────────────
    Rectangle {
        width: parent.width
        visible: Displays.confirming
        implicitHeight: 64
        radius: Appearance.sizes.radius
        color: Appearance.colors.primaryContainer

        StyledText {
            anchors.left: parent.left
            anchors.leftMargin: 18
            anchors.right: confirmButtons.left
            anchors.verticalCenter: parent.verticalCenter
            text: `Keep these display settings? Reverting in ${Displays.confirmLeft} s`
            color: Appearance.colors.onPrimaryContainer
            font.pointSize: Appearance.font.normal + 0.5
        }
        Row {
            id: confirmButtons
            anchors.right: parent.right
            anchors.rightMargin: 14
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            PillButton {
                label: "Revert"
                onClicked: Displays.revert()
            }
            PillButton {
                label: "Keep"
                primary: true
                onClicked: Displays.keep()
            }
        }
    }

    // ── Arrangement ──────────────────────────────────────────────────
    Rectangle {
        id: canvas

        readonly property var outs: Displays.enabledOutputs
        readonly property real minX: Math.min(...outs.map(o => o.x))
        readonly property real minY: Math.min(...outs.map(o => o.y))
        readonly property real maxX: Math.max(...outs.map(o => o.x + Displays.logical(o).width))
        readonly property real maxY: Math.max(...outs.map(o => o.y + Displays.logical(o).height))
        // Logical pixels → canvas pixels, leaving room to drag around.
        readonly property real f: outs.length ? Math.min((width - 80) / (maxX - minX), (height - 90) / (maxY - minY)) : 1
        readonly property real ox: (width - (maxX - minX) * f) / 2
        // Below the hint line.
        readonly property real oy: 36 + (height - 36 - (maxY - minY) * f) / 2

        width: parent.width
        height: 280
        radius: Appearance.sizes.radius
        color: Appearance.colors.surface

        Hint {
            x: 16
            y: 12
            width: parent.width - 32
            text: canvas.outs.length > 1 ? "Drag the displays to arrange them. Click one to change it below."
                : Displays.outputs.length ? "Click a display to change it below." : "Reading displays…"
        }

        Repeater {
            model: canvas.outs

            Rectangle {
                id: screenRect
                required property var modelData
                readonly property size logical: Displays.logical(modelData)
                readonly property bool isSelected: root.current?.name === modelData.name
                readonly property real homeX: canvas.ox + (modelData.x - canvas.minX) * canvas.f
                readonly property real homeY: canvas.oy + (modelData.y - canvas.minY) * canvas.f

                x: homeX
                y: homeY
                width: logical.width * canvas.f
                height: logical.height * canvas.f
                radius: 10
                color: isSelected ? Appearance.colors.primaryContainer : Appearance.colors.surfaceHigh
                border.width: isSelected ? 2 : 1
                border.color: isSelected ? Appearance.colors.primary : Appearance.colors.outline
                z: drag.active ? 2 : isSelected ? 1 : 0

                // Snap back to the real position whenever the layout changes.
                onHomeXChanged: x = homeX
                onHomeYChanged: y = homeY

                Column {
                    anchors.centerIn: parent
                    width: parent.width - 16
                    spacing: 2

                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: screenRect.modelData.name
                        font.bold: true
                        color: screenRect.isSelected ? Appearance.colors.onPrimaryContainer : Appearance.colors.text
                    }
                    StyledText {
                        width: parent.width
                        horizontalAlignment: Text.AlignHCenter
                        text: `${screenRect.modelData.width}×${screenRect.modelData.height}`
                        font.pointSize: Appearance.font.small
                        color: Appearance.colors.textDim
                    }
                    StyledText {
                        width: parent.width
                        visible: Displays.isPrimary(screenRect.modelData.name)
                        horizontalAlignment: Text.AlignHCenter
                        text: "Primary"
                        font.pointSize: Appearance.font.small
                        color: Appearance.colors.primary
                    }
                }

                TapHandler {
                    onTapped: root.selected = screenRect.modelData.name
                }

                DragHandler {
                    id: drag
                    enabled: canvas.outs.length > 1
                    onActiveChanged: {
                        if (active) {
                            root.selected = screenRect.modelData.name;
                            return;
                        }
                        screenRect.drop();
                    }
                }

                // Snap the dropped display against the others' edges, then
                // send the new layout to KScreen.
                function drop(): void {
                    const w = logical.width, h = logical.height;
                    let px = (x - canvas.ox) / canvas.f + canvas.minX;
                    let py = (y - canvas.oy) / canvas.f + canvas.minY;
                    const others = canvas.outs.filter(o => o.name !== modelData.name);
                    const snapX = [], snapY = [];
                    for (const o of others) {
                        const l = Displays.logical(o);
                        // Beside it (touching), or aligned with its edges.
                        snapX.push(o.x + l.width, o.x - w, o.x, o.x + l.width - w);
                        snapY.push(o.y + l.height, o.y - h, o.y, o.y + l.height - h);
                    }
                    const nearest = (v, list) => list.reduce((b, c) => Math.abs(c - v) < Math.abs(b - v) ? c : b, list[0]);
                    const tolerance = 24 / canvas.f; // 24 px on the canvas
                    const nx = nearest(px, snapX), ny = nearest(py, snapY);
                    if (Math.abs(nx - px) < tolerance) px = nx;
                    if (Math.abs(ny - py) < tolerance) py = ny;
                    // Keep it touching something: KWin leaves gaps as dead
                    // space the pointer can't cross.
                    const touches = others.some(o => {
                        const l = Displays.logical(o);
                        const overlapY = py < o.y + l.height && py + h > o.y;
                        const overlapX = px < o.x + l.width && px + w > o.x;
                        return (overlapY && (px === o.x + l.width || px + w === o.x))
                            || (overlapX && (py === o.y + l.height || py + h === o.y));
                    });
                    if (!touches) {
                        x = homeX;
                        y = homeY;
                        return;
                    }
                    const positions = {};
                    positions[modelData.name] = Qt.point(px, py);
                    Displays.setPositions(positions);
                }
            }
        }
    }

    // Every connected output, disabled ones too (they aren't on the canvas).
    Flow {
        width: parent.width
        spacing: 8
        visible: Displays.outputs.length > 1

        Repeater {
            model: Displays.outputs
            PillButton {
                required property var modelData
                label: modelData.name + (modelData.enabled ? "" : " (off)")
                primary: root.current?.name === modelData.name
                onClicked: root.selected = modelData.name
            }
        }
    }

    // ── Selected output ──────────────────────────────────────────────
    Heading {
        visible: root.current !== null
        text: root.current?.name ?? ""
    }

    SettingRow {
        visible: root.current !== null && Displays.outputs.length > 1
        icon: "video-display-symbolic"
        label: "Enabled"
        description: root.current?.enabled && Displays.enabledOutputs.length <= 1
            ? "The only display that's on can't be turned off." : "Turn the display off without unplugging it."
        StyledSwitch {
            checked: root.current?.enabled ?? false
            enabled: !(checked && Displays.enabledOutputs.length <= 1)
            onToggled: Displays.setEnabled(root.current.name, !checked)
        }
    }

    SettingRow {
        visible: root.current?.enabled ?? false
        icon: "starred-symbolic"
        label: "Primary display"
        description: Displays.isPrimary(root.current?.name ?? "")
            ? "Notifications, and the bar and notch when they're kept to one display, show here."
            : "Make this the main display."
        PillButton {
            visible: !Displays.isPrimary(root.current?.name ?? "")
            label: "Make primary"
            onClicked: Displays.setPrimary(root.current.name)
        }
    }

    Block {
        visible: root.current?.enabled ?? false
        label: "Orientation"
        description: "How the screen is mounted. Portrait turns it 90°."

        Repeater {
            model: [["none", "Landscape"], ["left", "Portrait"], ["inverted", "Landscape (flipped)"], ["right", "Portrait (flipped)"]]
            PillButton {
                required property var modelData
                label: modelData[1]
                primary: Displays.rotations[root.current?.rotation] === modelData[0]
                onClicked: Displays.setRotation(root.current.name, modelData[0])
            }
        }
    }

    Block {
        id: resolution
        visible: root.current?.enabled ?? false
        // Mode sizes are unrotated; the output's size is rotated.
        readonly property var mode: root.current?.modes.find(m => m.id === root.current.modeId) ?? null
        readonly property var sizes: {
            const seen = [];
            for (const m of root.current?.modes ?? []) {
                const k = `${m.width}x${m.height}`;
                if (!seen.includes(k))
                    seen.push(k);
            }
            return seen;
        }
        label: "Resolution"

        Repeater {
            model: resolution.sizes
            PillButton {
                required property string modelData
                label: modelData.replace("x", "×")
                primary: resolution.mode && `${resolution.mode.width}x${resolution.mode.height}` === modelData
                onClicked: {
                    // Keep the refresh rate as close as possible.
                    const [w, h] = modelData.split("x").map(Number);
                    const same = root.current.modes.filter(m => m.width === w && m.height === h);
                    const want = resolution.mode?.refresh ?? 60;
                    const best = same.reduce((b, m) => Math.abs(m.refresh - want) < Math.abs(b.refresh - want) ? m : b, same[0]);
                    Displays.setMode(root.current.name, best.id);
                }
            }
        }
    }

    Block {
        visible: (root.current?.enabled ?? false) && rates.count > 1
        label: "Refresh rate"

        Repeater {
            id: rates
            model: (root.current?.modes ?? []).filter(m => resolution.mode && m.width === resolution.mode.width && m.height === resolution.mode.height)
            PillButton {
                required property var modelData
                label: `${modelData.refresh.toFixed(modelData.refresh % 1 > 0.05 && modelData.refresh % 1 < 0.95 ? 2 : 0)} Hz`
                primary: root.current?.modeId === modelData.id
                onClicked: Displays.setMode(root.current.name, modelData.id)
            }
        }
    }

    Block {
        visible: root.current?.enabled ?? false
        label: "Scale"
        description: "Makes text and the shell bigger on high-resolution displays."

        Repeater {
            model: [1, 1.25, 1.5, 1.75, 2]
            PillButton {
                required property real modelData
                label: `${Math.round(modelData * 100)}%`
                primary: Math.abs((root.current?.scale ?? 1) - modelData) < 0.01
                onClicked: Displays.setScale(root.current.name, modelData)
            }
        }
    }

    // ── Several displays ─────────────────────────────────────────────
    Heading {
        text: "Multiple displays"
    }

    Block {
        label: "Sidebar"
        description: "The bar with workspaces, apps, tray and status icons."
        Repeater {
            model: [["all", "All displays"], ["primary", "Primary only"]]
            PillButton {
                required property var modelData
                label: modelData[1]
                primary: Settings.options.barDisplays === modelData[0]
                onClicked: Settings.options.barDisplays = modelData[0]
            }
        }
    }

    Block {
        label: "Notch"
        description: "The island at the top. The dashboard opens from it, so it follows the notch."
        Repeater {
            model: [["all", "All displays"], ["primary", "Primary only"]]
            PillButton {
                required property var modelData
                label: modelData[1]
                primary: Settings.options.notchDisplays === modelData[0]
                onClicked: Settings.options.notchDisplays = modelData[0]
            }
        }
    }

    Block {
        label: "Notification popups"
        Repeater {
            model: [["primary", "Primary display"], ["active", "Display with the active window"]]
            PillButton {
                required property var modelData
                label: modelData[1]
                primary: Settings.options.popupDisplays === modelData[0]
                onClicked: Settings.options.popupDisplays = modelData[0]
            }
        }
    }
}
