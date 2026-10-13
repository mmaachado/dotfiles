import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Widgets

// Icon from the active KDE icon theme. Set `color` to tint it (for symbolic icons
// on coloured backgrounds); leave it transparent to keep the theme's own colours.
IconImage {
    id: root

    property string name
    property string fallback: "application-x-executable"
    property color color: "transparent"
    property int size: 22

    implicitSize: size
    asynchronous: true
    source: name.startsWith("/") || name.startsWith("file:") || name.startsWith("image:")
        ? (name.startsWith("/") ? "file://" + name : name) : Quickshell.iconPath(name, fallback)

    layer.enabled: root.color.a > 0
    layer.effect: MultiEffect {
        brightness: 1
        colorization: 1
        colorizationColor: root.color
    }
}
