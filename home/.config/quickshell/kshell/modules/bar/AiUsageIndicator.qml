import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// AI plan usage beside the tray (ai-usagebar): a small ring with the most
// used provider's percentage, coloured by level. Click for every
// provider's usage and reset time.
Item {
    id: root

    readonly property bool vertical: Appearance.barVertical
    readonly property var best: AiUsage.top

    visible: AiUsage.shown
    implicitWidth: vertical ? Appearance.sizes.barWidth - 12 : pill.width
    implicitHeight: vertical ? pill.height : Appearance.sizes.barWidth - 12

    Connections {
        target: AiUsage
        function onToggleRequested(): void {
            const screen = QsWindow.window?.screen?.name ?? "";
            if (screen === Bridge.activeScreen || Quickshell.screens.length === 1)
                popup.visible = !popup.visible;
        }
    }

    function levelColor(p: real): color {
        return p >= 90 ? Appearance.colors.error : p >= 70 ? "#f2a33a" : Appearance.colors.primary;
    }

    Rectangle {
        id: pill
        anchors.centerIn: parent
        width: root.vertical ? Appearance.sizes.barWidth - 12 : ring.width + 16
        height: root.vertical ? ring.height + 16 : Appearance.sizes.barWidth - 12
        radius: Math.min(width, height) / 2
        color: popup.visible ? Appearance.colors.primaryContainer : Appearance.colors.surface

        Ring {
            id: ring
            anchors.centerIn: parent
            width: 28
            implicitWidth: 28
            implicitHeight: 28
            stroke: 3
            value: (root.best?.percent ?? 0) / 100
            color: root.levelColor(root.best?.percent ?? 0)
            text: root.best ? Math.round(root.best.percent) : "–"
        }

        StateLayer {
            id: layer
            radius: pill.radius
            onClicked: popup.visible = !popup.visible
        }
    }

    Tooltip {
        text: root.best ? `${root.best.name} · ${root.best.label}: ${Math.round(root.best.percent)}% used` : "AI usage"
        shown: tip.shown && !popup.visible
    }
    HoverDelay {
        id: tip
        hovered: layer.containsMouse
    }

    // Every provider, in a popup that opens away from the bar's edge.
    PopupWindow {
        id: popup
        readonly property string edge: Appearance.barPosition
        anchor.item: pill
        anchor.rect.x: edge === "left" ? pill.width + 12 : edge === "right" ? -width - 12 : (pill.width - width) / 2
        anchor.rect.y: edge === "top" ? pill.height + 12 : edge === "bottom" ? -height - 12 : (pill.height - height) / 2
        implicitWidth: 320
        implicitHeight: card.implicitHeight
        color: "transparent"
        visible: false

        onVisibleChanged: if (visible) AiUsage.refresh()

        Rectangle {
            id: card
            anchors.fill: parent
            implicitHeight: content.implicitHeight + 32
            radius: Appearance.sizes.radius
            color: Appearance.colors.surface
            border.width: 1
            border.color: Qt.alpha(Appearance.colors.outline, 0.4)

            Column {
                id: content
                x: 16
                y: 16
                width: parent.width - 32
                spacing: 14

                StyledText {
                    text: "AI usage"
                    font.pointSize: Appearance.font.large
                    font.bold: true
                }

                Repeater {
                    model: AiUsage.providers

                    // A provider: its name and plan, then each limit.
                    Column {
                        id: provider
                        required property var modelData
                        width: content.width
                        spacing: 8

                        Row {
                            spacing: 8
                            StyledText {
                                text: provider.modelData.name
                                font.bold: true
                            }
                            StyledText {
                                anchors.baseline: parent.children[0].baseline
                                text: provider.modelData.plan
                                color: Appearance.colors.textDim
                                font.pointSize: Appearance.font.small
                            }
                        }

                        Repeater {
                            model: provider.modelData.metrics

                            Column {
                                required property var modelData
                                width: provider.width
                                spacing: 4

                                Item {
                                    width: parent.width
                                    height: labelText.implicitHeight
                                    StyledText {
                                        id: labelText
                                        text: modelData.label
                                        font.pointSize: Appearance.font.small
                                    }
                                    StyledText {
                                        anchors.right: parent.right
                                        text: `${Math.round(modelData.percent)}%`
                                        color: root.levelColor(modelData.percent)
                                        font.bold: true
                                        font.pointSize: Appearance.font.small
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    height: 6
                                    radius: 3
                                    color: Appearance.colors.secondaryContainer
                                    Rectangle {
                                        width: parent.width * Math.min(1, modelData.percent / 100)
                                        height: parent.height
                                        radius: 3
                                        color: root.levelColor(modelData.percent)
                                    }
                                }
                                StyledText {
                                    width: parent.width
                                    visible: text !== ""
                                    text: modelData.detail
                                    color: Appearance.colors.textDim
                                    font.pointSize: Appearance.font.small
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }

                StyledText {
                    width: parent.width
                    visible: AiUsage.providers.length === 0
                    wrapMode: Text.WordWrap
                    text: AiUsage.error || "No usage yet. Configure providers in ~/.config/ai-usagebar/config.toml."
                    color: Appearance.colors.textDim
                }

                Row {
                    spacing: 8
                    Rectangle {
                        width: cfgText.implicitWidth + 24
                        height: 30
                        radius: 15
                        color: Appearance.colors.surfaceHigh
                        StyledText {
                            id: cfgText
                            anchors.centerIn: parent
                            text: "Configure…"
                            font.pointSize: Appearance.font.small
                        }
                        StateLayer {
                            onClicked: {
                                AiUsage.configure();
                                popup.visible = false;
                            }
                        }
                    }
                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: AiUsage.updated ? `Updated ${AiUsage.updated}` : ""
                        color: Appearance.colors.textFaint
                        font.pointSize: Appearance.font.small
                    }
                }
            }
        }
    }
}
