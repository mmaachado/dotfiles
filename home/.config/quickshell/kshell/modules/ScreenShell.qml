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
    // Width of the frame's left side: the bar, or just the border.
    readonly property real leftInset: Appearance.sizes.border + (Appearance.sizes.barWidth - Appearance.sizes.border) * barShown
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
    readonly property real drawerRoom: modelData.width - root.leftInset - Appearance.sizes.border
        - 2 * Appearance.sizes.rounding - 2 * Appearance.sizes.padding - 16

    readonly property bool merged: Bridge.currentWindows.some(w => !w.minimized
        && (w.output === root.modelData.name || Quickshell.screens.length === 1)
        && (w.maximized || w.fullscreen
            || (w.y - root.modelData.y < root.notchH + 8 && w.x < root.notchRight && w.x + w.width > root.notchLeft)))
    // No bounce: the notch must not poke out past flat or past its full height.
    readonly property real merge: Math.min(1, Math.max(0, mergeSpring.value))
    Spring {
        id: mergeSpring
        target: root.merged ? 1 : 0
        preset: Appearance.spring.slowEffects
    }

    Exclusions {
        screen: root.modelData
        leftZone: root.showBar ? Appearance.sizes.barWidth : Appearance.sizes.border
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
        WlrLayershell.keyboardFocus: root.drawerOpen && (Visibilities.launcher || Visibilities.session || Visibilities.wallpapers || Visibilities.themes || Visibilities.clipboard)
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
                    x: root.leftInset
                    y: Appearance.sizes.border
                    width: win.width - root.leftInset - Appearance.sizes.border
                    height: win.height - 2 * Appearance.sizes.border
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
                topLeftRadius: Appearance.sizes.rounding
                bottomLeftRadius: Appearance.sizes.rounding
            }
            Region {
                item: osdDrawer.body
                topLeftRadius: Appearance.sizes.rounding
                bottomLeftRadius: Appearance.sizes.rounding
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
                        x: root.leftInset
                        y: Appearance.sizes.border
                        width: win.width - root.leftInset - Appearance.sizes.border
                        height: win.height - 2 * Appearance.sizes.border
                        radius: Appearance.sizes.rounding
                    }
                }
            }

            Bar {
                id: bar
                screenName: root.modelData.name
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                // Slides out past the left edge when hidden.
                anchors.leftMargin: -Appearance.sizes.barWidth * (1 - root.barShown)
                opacity: root.barShown
                visible: root.barShown > 0
            }

            // ── Drawers ───────────────────────────────────────────────
            Island {
                id: island
                screenName: root.modelData.name
                here: root.here
                merge: root.merge
                // Rises into the top edge when hidden.
                y: Appearance.sizes.border - (height + Appearance.sizes.border) * (1 - root.notchShown)
                opacity: root.notchShown
                visible: root.notchShown > 0
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.leftInset / 2 - Appearance.sizes.border / 2
            }

            Drawer {
                id: launcherDrawer
                edge: "bottom"
                open: Visibilities.launcher && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.border
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.leftInset / 2 - Appearance.sizes.border / 2

                Launcher {
                    open: Visibilities.launcher && root.here
                }
            }

            Drawer {
                id: wallpaperDrawer
                edge: "bottom"
                open: Visibilities.wallpapers && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.border
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.leftInset / 2 - Appearance.sizes.border / 2

                WallpaperPicker {
                    maxWidth: root.drawerRoom
                    open: Visibilities.wallpapers && root.here
                }
            }

            Drawer {
                id: clipboardDrawer
                edge: "bottom"
                open: Visibilities.clipboard && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.border
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.leftInset / 2 - Appearance.sizes.border / 2

                ClipboardPicker {
                    open: Visibilities.clipboard && root.here
                }
            }

            Drawer {
                id: themeDrawer
                edge: "bottom"
                open: Visibilities.themes && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.border
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: root.leftInset / 2 - Appearance.sizes.border / 2

                ThemePicker {
                    maxWidth: root.drawerRoom
                    open: Visibilities.themes && root.here
                }
            }

            Drawer {
                id: sessionDrawer
                edge: "right"
                open: Visibilities.session && root.here
                anchors.right: parent.right
                anchors.rightMargin: Appearance.sizes.border
                anchors.verticalCenter: parent.verticalCenter

                Session {
                    open: Visibilities.session && root.here
                }
            }

            // OSD: on the screen with the active window, out of the way
            // of the session menu.
            Drawer {
                id: osdDrawer
                edge: "right"
                open: Osd.shown && Osd.enabled && !(Visibilities.session && root.here)
                    && (Bridge.activeScreen === root.modelData.name || Quickshell.screens.length === 1)
                anchors.right: parent.right
                anchors.rightMargin: Appearance.sizes.border
                anchors.verticalCenter: parent.verticalCenter

                OsdView {}
            }

            Popups {
                id: popups
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Appearance.sizes.border + 12
                anchors.rightMargin: Appearance.sizes.border + 12
                // On the primary display (KScreen's, see Displays), or
                // wherever the active window is.
                visible: Settings.options.popupDisplays === "active"
                    ? (Bridge.activeScreen === root.modelData.name || root.single) : root.isPrimary
            }
        }
    }
}
