import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.components
import qs.config
import qs.services

// "Dynamic island" notch hanging from the top of the frame. It shows the time,
// what's playing and unread notifications, and morphs into the dashboard
// when hovered (or when the dashboard is opened from the bar / shortcut).
Item {
    id: root

    required property string screenName
    required property bool here
    // 0 = hanging notch, 1 = flattened into the frame's top edge, leaving a
    // small clock there (ScreenShell animates it).
    required property real merge

    readonly property bool expanded: Visibilities.dashboard && here
    readonly property int pad: Appearance.sizes.padding
    readonly property real r: Appearance.sizes.rounding

    readonly property real collapsedW: notch.implicitWidth + 36
    readonly property real collapsedH: Appearance.sizes.notchHeight
    readonly property real expandedW: dash.implicitWidth + pad * 2
    readonly property real expandedH: dash.implicitHeight + pad * 2

    property real t: expanded ? 1 : 0
    Behavior on t {
        NumberAnimation {
            duration: root.expanded ? Appearance.anim.slow : Appearance.anim.normal
            easing.type: Easing.BezierSpline
            easing.bezierCurve: root.expanded ? Appearance.anim.enter : Appearance.anim.exit
        }
    }

    width: shape.width
    height: shape.height

    // ── Hover to open, leave to close (only if hover opened it) ──────
    property bool openedByHover: false
    readonly property Item bodyItem: body
    readonly property real cornerRadius: shape.rr
    // Strip of the top edge over the notch, so hovering it still opens the
    // dashboard when the notch has flattened (ScreenShell adds it to the input mask).
    readonly property Item edgeItem: edge
    readonly property bool hovered: hover.hovered || edgeHover.hovered

    HoverHandler {
        id: hover
    }

    Item {
        id: edge
        x: root.r
        y: -Appearance.sizes.border
        width: root.collapsedW
        height: Appearance.sizes.border
        visible: root.merge > 0.5 && !root.expanded

        HoverHandler {
            id: edgeHover
        }
        TapHandler {
            onTapped: Visibilities.show("dashboard", root.screenName)
        }

        // Small clock left in the edge.
        StyledText {
            anchors.centerIn: parent
            text: Time.format(Time.use24h ? "hh:mm" : "h:mm AP")
            font.pointSize: 6
            font.bold: true
            color: Appearance.colors.textDim
            opacity: Math.max(0, root.merge * 2 - 1)
        }
    }

    Timer {
        running: root.hovered && !root.expanded
        interval: 180
        onTriggered: {
            root.openedByHover = true;
            Visibilities.show("dashboard", root.screenName);
        }
    }

    Timer {
        running: !root.hovered && root.expanded && root.openedByHover
        interval: 400
        onTriggered: Visibilities.closeAll()
    }

    onExpandedChanged: if (!expanded) openedByHover = false

    // ── Shape ────────────────────────────────────────────────────────
    DrawerShape {
        id: shape
        edge: "top"
        length: root.collapsedW + (root.expandedW - root.collapsedW) * root.t
        // Collapsed, the notch slides up into the top edge as it merges.
        readonly property real collapsedDepth: root.collapsedH * (1 - root.merge)
        depth: collapsedDepth + (root.expandedH - collapsedDepth) * root.t
    }

    Item {
        id: body
        x: root.r
        width: shape.length
        height: shape.depth
        clip: true

        // Collapsed content
        Row {
            id: notch
            readonly property MprisPlayer player: Players.active
            readonly property bool playing: player?.isPlaying ?? false

            anchors.horizontalCenter: parent.horizontalCenter
            // Rides up with the notch as it flattens.
            y: (root.collapsedH - height) / 2 - root.collapsedH * root.merge
            height: 22
            spacing: 10
            opacity: Math.max(0, 1 - root.t * 4) * (1 - root.merge)
            visible: opacity > 0

            // Clock: time, date or both (Settings → Notch).
            StyledText {
                readonly property string time: Time.format(Time.use24h ? "hh:mm" : "h:mm AP")
                readonly property string date: Time.format("ddd d MMM")

                anchors.verticalCenter: parent.verticalCenter
                text: Settings.options.notchClock === "date" ? date
                    : Settings.options.notchClock === "datetime" ? `${date}  ·  ${time}`
                    : time
                font.bold: true
            }

            // Now playing
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8
                visible: notch.playing && Settings.options.notchMedia

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: Appearance.colors.textFaint
                }

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 20
                    height: 20
                    radius: 6
                    color: Appearance.colors.surfaceHigh
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: notch.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize: Qt.size(40, 40)
                        asynchronous: true
                    }
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, 240)
                    text: [notch.player?.trackTitle, notch.player?.trackArtist].filter(s => s).join(" — ")
                    color: Appearance.colors.textDim
                }

                // Little equaliser
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2

                    Repeater {
                        model: 3

                        Rectangle {
                            id: eqBar
                            required property int index
                            anchors.verticalCenter: parent.verticalCenter
                            width: 3
                            height: 6
                            radius: 1.5
                            color: Appearance.colors.primary

                            SequentialAnimation on height {
                                running: notch.playing && root.t === 0 && Appearance.motion > 0
                                loops: Animation.Infinite
                                NumberAnimation { to: 14 - eqBar.index * 3; duration: 260 + eqBar.index * 90; easing.type: Easing.InOutSine }
                                NumberAnimation { to: 5; duration: 300 + eqBar.index * 70; easing.type: Easing.InOutSine }
                            }
                        }
                    }
                }
            }

            // Notifications / DND
            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                visible: Settings.options.notchNotifications && (Notifs.list.length > 0 || Visibilities.dnd)

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 4
                    height: 4
                    radius: 2
                    color: Appearance.colors.textFaint
                }

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: Visibilities.dnd ? "notifications-disabled-symbolic" : "notifications-symbolic"
                    size: 16
                    color: Appearance.colors.text
                }

                StyledText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: Notifs.list.length > 0
                    text: Notifs.list.length
                    font.bold: true
                    color: Appearance.colors.primary
                }
            }
        }

        // Expanded content, pinned to the bottom so it slides down with the island.
        Dashboard {
            id: dash
            open: root.expanded
            x: (body.width - width) / 2
            y: body.height - root.pad - height
            opacity: Math.min(1, Math.max(0, root.t * 2 - 0.6))
            visible: root.t > 0
        }
    }

    // Click the notch to pin the dashboard open (it then stays until closed).
    TapHandler {
        enabled: !root.expanded
        onTapped: Visibilities.show("dashboard", root.screenName)
    }
}
