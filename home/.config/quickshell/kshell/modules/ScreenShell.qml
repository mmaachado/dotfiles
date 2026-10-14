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

    Exclusions {
        screen: root.modelData
    }

    PanelWindow {
        id: win

        screen: root.modelData
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "kshell"
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.keyboardFocus: root.drawerOpen && (Visibilities.launcher || Visibilities.session || Visibilities.wallpapers)
            ? WlrKeyboardFocus.Exclusive : root.drawerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None

        mask: root.drawerOpen ? fullRegion : idleRegion

        Region {
            id: fullRegion
            item: content
        }
        Region {
            id: idleRegion
            item: bar
            Region { item: popups }
            Region { item: island }
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
                        x: Appearance.sizes.barWidth
                        y: Appearance.sizes.border
                        width: win.width - Appearance.sizes.barWidth - Appearance.sizes.border
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
            }

            // ── Drawers ───────────────────────────────────────────────
            Island {
                id: island
                screenName: root.modelData.name
                here: root.here
                y: Appearance.sizes.border
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: Appearance.sizes.barWidth / 2 - Appearance.sizes.border / 2
            }

            Drawer {
                edge: "bottom"
                open: Visibilities.launcher && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.border
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: Appearance.sizes.barWidth / 2 - Appearance.sizes.border / 2

                Launcher {
                    open: Visibilities.launcher && root.here
                }
            }

            Drawer {
                edge: "bottom"
                open: Visibilities.wallpapers && root.here
                anchors.bottom: parent.bottom
                anchors.bottomMargin: Appearance.sizes.border
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.horizontalCenterOffset: Appearance.sizes.barWidth / 2 - Appearance.sizes.border / 2

                WallpaperPicker {
                    open: Visibilities.wallpapers && root.here
                }
            }

            Drawer {
                edge: "right"
                open: Visibilities.session && root.here
                anchors.right: parent.right
                anchors.rightMargin: Appearance.sizes.border
                anchors.verticalCenter: parent.verticalCenter

                Session {
                    open: Visibilities.session && root.here
                }
            }

            Popups {
                id: popups
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: Appearance.sizes.border + 12
                anchors.rightMargin: Appearance.sizes.border + 12
                // Only on the primary screen.
                visible: root.modelData === Quickshell.screens[0]
            }
        }
    }
}
