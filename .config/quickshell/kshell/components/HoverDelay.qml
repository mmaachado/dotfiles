import QtQuick

// `shown` turns true after hovering for `delay` ms.
Timer {
    property bool hovered
    property bool shown

    interval: 500
    running: hovered && !shown
    onTriggered: shown = true
    onHoveredChanged: if (!hovered) shown = false
}
