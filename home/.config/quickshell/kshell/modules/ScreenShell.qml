import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import qs.components
import qs.config
import qs.services
import qs.modules.bar
import qs.modules.drawers
import qs.modules.notifications

// Everything visible on one screen lives in a single full-screen, click-through
// layer surface: the frame, bar, drawers and popups. Input is limited to the
// bar + popups via `mask`, or the whole screen while a drawer is open (so a
// click outside closes it).
Scope {
    id: root

    required property ShellScreen modelData
    readonly property bool here: Visibilities.screen === "" || Visibilities.screen === modelData.name
        || Quickshell.screens.length === 1
    readonly property bool drawerOpen: Visibilities.anyOpen && here
    readonly property bool isPrimary: modelData.name === Displays.primary
    readonly property bool single: Quickshell.screens.length === 1

    // The bar and the notch can be kept to the primary display (Settings →
    // Displays). Without the bar the frame is a thin border on all sides.
    readonly property bool showBar: Settings.options.barDisplays !== "primary" || isPrimary || single
    readonly property bool showNotch: Settings.options.notchDisplays !== "primary" || isPrimary || single
    readonly property real barShown: Math.min(1, Math.max(0, barSpring.value))
    readonly property real notchShown: Math.min(1, Math.max(0, notchSpring.value))
    // The frame's thickness on each side: the bar's side gets the bar (as
    // far as it's slid in), the others just the border.
    readonly property string side: Appearance.barPosition
    readonly property real barInset: Appearance.sizes.border + (Appearance.sizes.barWidth - Appearance.sizes.border) * barShown
    readonly property real insetLeft: side === "left" ? barInset : Appearance.sizes.border
    readonly property real insetTop: side === "top" ? barInset : Appearance.sizes.border
    readonly property real insetRight: side === "right" ? barInset : Appearance.sizes.border
    readonly property real insetBottom: side === "bottom" ? barInset : Appearance.sizes.border
    // Shift that centres things in the frame's hole rather than the screen.
    readonly property real centerOffset: (insetLeft - insetRight) / 2
    // The session menu and OSD slide in from the right, or from the left
    // when the bar is on the right.
    readonly property string sideDrawerEdge: side === "right" ? "left" : "right"
    Spring {
        id: barSpring
        target: root.showBar ? 1 : 0
        preset: root.showBar ? Appearance.spring.defaultSpatial : Appearance.spring.exit
    }
    Spring {
        id: notchSpring
        target: root.showNotch ? 1 : 0
        preset: root.showNotch ? Appearance.spring.defaultSpatial : Appearance.spring.exit
    }
    Component.onCompleted: {
        barSpring.snap(barSpring.target);
        notchSpring.snap(notchSpring.target);
    }

    // The notch flattens into the frame's top edge while a window is
    // maximized, fullscreen, or close enough to the notch that it would be covered.
    readonly property real notchH: Appearance.sizes.notchHeight
    readonly property real notchLeft: modelData.x + island.x + island.cornerRadius - 8
    readonly property real notchRight: notchLeft + island.collapsedW + 16
    // Widest a bottom drawer can be and still fit (portrait screens).
    readonly property real drawerRoom: modelData.width - root.insetLeft - root.insetRight
        - 2 * Appearance.sizes.rounding - 2 * Appearance.sizes.padding - 16

    readonly property bool merged: Bridge.currentWindows.some(w => !w.minimized
        && (w.output === root.modelData.name || Quickshell.screens.length === 1)
        && (w.maximized || w.fullscreen
            || (w.y - root.modelData.y < root.insetTop - Appearance.sizes.border + root.notchH + 8 && w.x < root.notchRight && w.x + w.width > root.notchLeft)))
    // No bounce: the notch must not poke out past flat or past its full height.
    readonly property real merge: Math.min(1, Math.max(0, mergeSpring.value))
    Spring {
        id: mergeSpring
        target: root.merged ? 1 : 0
        preset: Appearance.spring.slowEffects
    }

    Exclusions {
        screen: root.modelData
        readonly property real barZone: root.showBar ? Appearance.sizes.barWidth : Appearance.sizes.border
        leftZone: root.side === "left" ? barZone : Appearance.sizes.border
        topZone: root.side === "top" ? barZone : Appearance.sizes.border
        rightZone: root.side === "right" ? barZone : Appearance.sizes.border
        bottomZone: root.side === "bottom" ? barZone : Appearance.sizes.border
    }

    Backdrop {
        id: backdrop
        screen: root.modelData
    }

    WallpaperTransition {
        screen: root.modelData
        blurred: backdrop.shown
    }

    PanelWindow {
        id: win

        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "kshell"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.drawerOpen && (Visibilities.launcher || Visibilities.session || Visibilities.wallpapers || Visibilities.themes || Visibilities.clipboard || Visibilities.capture)
            ? WlrKeyboardFocus.Exclusive : root.drawerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: root.drawerOpen ? fullRegion : idleRegion

        // Blur themes: KWin blurs behind the frame and open drawers.
        BackgroundEffect.blurRegion: Appearance.blur ? blurRegion : null

        Region {
            id: blurRegion

            // Frame = whole screen minus the rounded hole.
            Region {
                item: content
                Region {
                    intersection: Intersection.Subtract
                    x: root.insetLeft
                    y: root.insetTop
                    width: win.width - root.insetLeft - root.insetRight
                    height: win.height - root.insetTop - root.insetBottom
                    radius: Appearance.sizes.rounding
                }
            }
            Region {
                item: root.showNotch ? island.bodyItem : null
                bottomLeftRadius: island.cornerRadius
                bottomRightRadius: island.cornerRadius
            }
            Region {
                item: launcherDrawer.body
                topLeftRadius: Appearance.sizes.rounding
                topRightRadius: Appearance.sizes.rounding
            }
            Region {
                item: wallpaperDrawer.body
                topLeftRadius: Appearance.sizes.rounding
                topRightRadius: Appearance.sizes.rounding
            }
            Region {
                item: captureDrawer.body
                topLeftRadius: Appearance.sizes.rounding
                topRightRadius: Appearance.sizes.rounding
            }
            Region {
                item: clipboardDrawer.body
                topLeftRadius: Appearance.sizes.rounding
                topRightRadius: Appearance.sizes.rounding
            }
            Region {
                item: themeDrawer.body
                topLeftRadius: Appearance.sizes.rounding
                topRightRadius: Appearance.sizes.rounding
            }
            Region {
                item: sessionDrawer.body
                readonly property real r: Appearance.sizes.rounding
                topLeftRadius: root.sideDrawerEdge === "right" ? r : 0
                bottomLeftRadius: root.sideDrawerEdge === "right" ? r : 0
                topRightRadius: root.sideDrawerEdge === "left" ? r : 0
                bottomRightRadius: root.sideDrawerEdge === "left" ? r : 0
            }
            Region {
                item: osdDrawer.body
                readonly property real r: Appearance.sizes.rounding
                topLeftRadius: root.sideDrawerEdge === "right" ? r : 0
                bottomLeftRadius: root.sideDrawerEdge === "right" ? r : 0
                topRightRadius: root.sideDrawerEdge === "left" ? r : 0
                bottomRightRadius: root.sideDrawerEdge === "left" ? r : 0
            }
        }

        Region {
            id: fullRegion
            item: content
        }
        Region {
            id: idleRegion
            item: root.showBar ? bar : null
            Region { item: popups }
            Region { item: captureThumb.visible ? captureThumb : null }
            Region { item: root.showNotch ? island : null }
            Region { item: root.showNotch ? island.edgeItem : null }
        }

        Item {
            id: content
            anchors.fill: parent
            focus: true
            Keys.onEscapePressed: Visibilities.closeAll()

            // Click outside a drawer → close.
            MouseArea {
                anchors.fill: parent
                enabled: root.drawerOpen
                acceptedButtons: Qt.AllButtons
                onPressed: Visibilities.closeAll()
            }

            // ── Frame: screen-sized rect with a rounded hole ──────────
            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    fillColor: Appearance.colors.frame
                    fillRule: ShapePath.OddEvenFill
                    strokeWidth: -1

                    PathRectangle {
                        width: win.width
                        height: win.height
                    }
                    PathRectangle {
                        x: root.insetLeft
                        y: root.insetTop
                        width: win.width - root.insetLeft - root.insetRight
                        height: win.height - root.insetTop - root.insetBottom
                        radius: Appearance.sizes.rounding
                    }
                }
            }

            Bar {
                id: bar
                screenName: root.modelData.name
                // Along its edge, and slid out past it when hidden.
                readonly property real hidden: -Appearance.sizes.barWidth * (1 - root.barShown)
                // Sized explicitly: unsetting an anchor would keep the size it
                // gave (a full-height bar turned horizontal stays full height).
                width: Appearance.barVertical ? Appearance.sizes.barWidth : parent.width
                height: Appearance.barVertical ? parent.height : Appearance.sizes.barWidth
                anchors.left: root.side !== "right" ? parent.left : undefined
                anchors.right: root.side === "right" ? parent.right : undefined
                anchors.top: root.side !== "bottom" ? parent.top : undefined
                anchors.bottom: root.side === "bottom" ? parent.bottom : undefined
                anchors.leftMargin: root.side === "left" ? hidden : 0
                anchors.rightMargin: root.side === "right" ? hidden : 0
                anchors.topMargin: root.side === "top" ? hidden : 0
                anchors.bottomMargin: root.side === "bottom" ? hidden : 0
                // Room in the middle of a horizontal bar: the notch hangs
                // there from a top bar, the launcher rises there from a bottom one.
                centerGap: root.side === "top" ? island.collapsedW + 2 * island.cornerRadius + 24
                    : 620 + 2 * Appearance.sizes.padding + 2 * Appearance.sizes.rounding
                opacity: root.barShown
                visible: root.barShown > 0
            }

            // ── Drawers ───────────────────────────────────────────────
            Island {
                id: island
                screenName: root.modelData.name
                here: root.here
                merge: root.merge
                topInset: root.insetTop
                // Rises into the top edge when hidden.
                y: root.insetTop - (height + root.insetTop) * (1 - root.notchShown)
                opacity: root.notchShown
                visible: root.notchShown > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset
            }

            Drawer {
                id: launcherDrawer
                edge: "bottom"
                open: Visibilities.launcher && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.insetBottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset

                Launcher {
                    open: Visibilities.launcher && root.here
                }
            }

            Drawer {
                id: wallpaperDrawer
                edge: "bottom"
                open: Visibilities.wallpapers && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.insetBottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset

                WallpaperPicker {
                    maxWidth: root.drawerRoom
                    open: Visibilities.wallpapers && root.here
                }
            }

            Drawer {
                id: captureDrawer
                edge: "bottom"
                open: Visibilities.capture && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.insetBottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset

                CaptureBar {
                    open: Visibilities.capture && root.here
                }
            }

            Drawer {
                id: clipboardDrawer
                edge: "bottom"
                open: Visibilities.clipboard && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.insetBottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset

                ClipboardPicker {
                    open: Visibilities.clipboard && root.here
                }
            }

            Drawer {
                id: themeDrawer
                edge: "bottom"
                open: Visibilities.themes && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: root.insetBottom
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.centerOffset

                ThemePicker {
                    maxWidth: root.drawerRoom
                    open: Visibilities.themes && root.here
                }
            }

            Drawer {
                id: sessionDrawer
                edge: root.sideDrawerEdge
                open: Visibilities.session && root.here
                anchors.right: edge === "right" ? parent.right : undefined
                anchors.left: edge === "left" ? parent.left : undefined
                anchors.rightMargin: root.insetRight
                anchors.leftMargin: root.insetLeft
                anchors.verticalCenter: parent.verticalCenter

                Session {
                    edge: root.sideDrawerEdge
                    open: Visibilities.session && root.here
                }
            }

            // OSD: on the screen with the active window, out of the way
            // of the session menu.
            Drawer {
                id: osdDrawer
                edge: root.sideDrawerEdge
                open: Osd.shown && Osd.enabled && !(Visibilities.session && root.here)
                    && (Bridge.activeScreen === root.modelData.name || Quickshell.screens.length === 1)
                anchors.right: edge === "right" ? parent.right : undefined
                anchors.left: edge === "left" ? parent.left : undefined
                anchors.rightMargin: root.insetRight
                anchors.leftMargin: root.insetLeft
                anchors.verticalCenter: parent.verticalCenter

                OsdView {}
            }

            // After a screenshot or recording, on the screen being used.
            CaptureThumb {
                id: captureThumb
                active: Bridge.activeScreen === root.modelData.name || root.single
                anchors.right: parent.right
                anchors.bottom: parent.bottom
                anchors.rightMargin: root.insetRight + 16
                anchors.bottomMargin: root.insetBottom + 16
            }

            Popups {
                id: popups
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: root.insetTop + 12
                anchors.rightMargin: root.insetRight + 12
                // On the primary display (KScreen's, see Displays), or
                // wherever the active window is.
                visible: Settings.options.popupDisplays === "active"
                    ? (Bridge.activeScreen === root.modelData.name || root.single) : root.isPrimary
            }
        }
    }
}
