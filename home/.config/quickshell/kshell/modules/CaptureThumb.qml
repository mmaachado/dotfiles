import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// The floating thumbnail after a capture, like macOS's: it slides into the
// corner for a few seconds (longer while hovered). Click to edit it in droid
// Markup (or open a recording), drag it into an app, or use the buttons to
// show it in its folder or move it to the trash.
Item {
    id: root

    // Only the screen that should show it (ScreenShell decides).
    property bool active
    property string path: ""
    property bool video: false
    property bool shown: false
    readonly property string url: path ? "file://" + path.split("/").map(encodeURIComponent).join("/") : ""
    readonly property string markup: Quickshell.env("HOME") + "/.local/bin/droid-markup"

    width: 240
    height: card.height
    visible: slide.value < 0.999

    Connections {
        target: Capture
        function onCaptured(path: string, video: bool): void {
            if (!root.active)
                return;
            root.path = path;
            root.video = video;
            root.shown = true;
            hide.restart();
        }
    }

    // 0 = in view, 1 = off past the right edge.
    Spring {
        id: slide
        value: 1
        target: root.shown ? 0 : 1
        preset: root.shown ? Appearance.spring.defaultSpatial : Appearance.spring.exit
    }

    Timer {
        id: hide
        interval: 5000
        running: root.shown && !hover.hovered && !drag.active
        onTriggered: root.shown = false
    }

    function open(): void {
        root.shown = false;
        if (root.video)
            Quickshell.execDetached(["xdg-open", root.path]);
        else
            // droid Markup if it's installed (`just apps-install`), else Spectacle's editor.
            Quickshell.execDetached(["sh", "-c", 'if [ -x "$1" ]; then exec "$1" "$2"; else exec spectacle -E "$2"; fi',
                "sh", root.markup, root.path]);
    }

    Rectangle {
        id: card
        x: slide.value * (root.width + 40)
        width: root.width
        height: root.video ? 90 : Math.max(90, Math.min(200, root.width * (preview.implicitHeight / Math.max(1, preview.implicitWidth))))
        radius: Appearance.sizes.radius
        color: Appearance.colors.surface
        border.width: 1
        border.color: Qt.alpha(Appearance.colors.outline, 0.5)
        clip: true

        Image {
            id: preview
            anchors.fill: parent
            visible: !root.video
            source: root.video ? "" : root.url
            sourceSize.width: 480
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
        }

        Row {
            anchors.centerIn: parent
            visible: root.video
            spacing: 10
            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: "media-playback-start-symbolic"
                size: 26
                color: Appearance.colors.primary
            }
            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Recording saved"
                font.bold: true
            }
        }

        HoverHandler {
            id: hover
        }

        // Click to open; drag the file into an app.
        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: root.open()
        }

        DragHandler {
            id: drag
            target: null
        }
        Drag.active: drag.active
        Drag.dragType: Drag.Automatic
        Drag.supportedActions: Qt.CopyAction
        Drag.mimeData: ({ "text/uri-list": root.url + "\r\n" })
        Drag.onDragFinished: root.shown = false

        // Buttons, on hover.
        Row {
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: 6
            spacing: 4
            opacity: hover.hovered ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Appearance.anim.fast }
            }

            component ThumbButton: Rectangle {
                id: btn
                property string icon
                property string tip
                signal clicked
                width: 28
                height: 28
                radius: 14
                color: Qt.alpha(Appearance.colors.surface, 0.85)
                Icon {
                    anchors.centerIn: parent
                    name: btn.icon
                    size: 15
                    color: Appearance.colors.text
                }
                StateLayer {
                    onClicked: btn.clicked()
                }
            }

            ThumbButton {
                icon: "folder-open-symbolic"
                onClicked: {
                    Quickshell.execDetached(["dolphin", "--select", root.path]);
                    root.shown = false;
                }
            }
            ThumbButton {
                icon: "edit-delete-symbolic"
                onClicked: {
                    Quickshell.execDetached(["gio", "trash", root.path]);
                    root.shown = false;
                }
            }
            ThumbButton {
                icon: "window-close-symbolic"
                onClicked: root.shown = false
            }
        }
    }
}
