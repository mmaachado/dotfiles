import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets
import qs.components
import qs.config

Pill {
    id: root

    spacing: 6
    padding: 10
    // Icons hidden in the settings window are left out.
    readonly property var shown: SystemTray.items.values.filter(i => !Settings.options.hiddenTray.includes(i.id))

    visible: shown.length > 0

    Repeater {
        model: root.shown

        Item {
            id: entry
            required property SystemTrayItem modelData

            width: Appearance.sizes.iconTray + 8
            height: width

            IconImage {
                anchors.centerIn: parent
                implicitSize: Appearance.sizes.iconTray
                source: {
                    // Some apps ship icons by path via ?path= — resolve them directly.
                    const icon = entry.modelData.icon;
                    if (icon.includes("?path=")) {
                        const [name, path] = icon.split("?path=");
                        return `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
                    }
                    return icon;
                }
            }

            StateLayer {
                id: layer
                radius: width / 2
                acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
                onClicked: mouse => {
                    const item = entry.modelData;
                    if (mouse.button === Qt.MiddleButton) {
                        item.secondaryActivate();
                    } else if (mouse.button === Qt.RightButton || item.onlyMenu) {
                        if (item.hasMenu) {
                            const p = entry.mapToItem(null, entry.width + 14, 0);
                            item.display(QsWindow.window, p.x, p.y);
                        }
                    } else {
                        item.activate();
                    }
                }
                onWheel: wheel => entry.modelData.scroll(wheel.angleDelta.y, false)
            }

            Tooltip {
                text: entry.modelData.tooltipTitle || entry.modelData.title
                shown: tip.shown
            }

            HoverDelay {
                id: tip
                hovered: layer.containsMouse
            }
        }
    }
}
