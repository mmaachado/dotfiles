import QtQuick
import Quickshell
import qs.components
import qs.config
import qs.services

// Session menu. Logout/reboot/shutdown go through KDE's ksmserver so the
// session is saved and apps get to close cleanly.
Column {
    id: root

    property bool open

    spacing: 14

    onOpenChanged: if (open) buttons.itemAt(0).forceActiveFocus()

    readonly property var actions: [
        // Same command as the Meta+L shortcut (net.local.sddm-lock.desktop)
        { icon: "system-lock-screen-symbolic", label: "Lock", cmd: ["sh", "-c", "exec \"$HOME/.local/bin/sddm-lock\""] },
        { icon: "system-log-out-symbolic", label: "Log out", cmd: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logout"] },
        { icon: "system-suspend-symbolic", label: "Sleep", cmd: ["systemctl", "suspend"] },
        { icon: "system-reboot-symbolic", label: "Restart", cmd: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logoutAndReboot"] },
        { icon: "system-shutdown-symbolic", label: "Shut down", cmd: ["qdbus6", "org.kde.Shutdown", "/Shutdown", "org.kde.Shutdown.logoutAndShutdown"] },
    ]

    Repeater {
        id: buttons
        model: root.actions

        Rectangle {
            id: btn
            required property var modelData
            required property int index

            width: 72
            height: 72
            radius: activeFocus ? Appearance.sizes.radius : width / 2
            color: activeFocus ? Appearance.colors.primary : Appearance.colors.surfaceHigh

            Behavior on radius {
                NumberAnimation { duration: Appearance.anim.normal; easing.type: Easing.OutCubic }
            }
            Behavior on color {
                ColorAnimation { duration: Appearance.anim.fast }
            }

            function run(): void {
                Visibilities.closeAll();
                Quickshell.execDetached(modelData.cmd);
            }

            Keys.onUpPressed: buttons.itemAt((index + root.actions.length - 1) % root.actions.length).forceActiveFocus()
            Keys.onDownPressed: buttons.itemAt((index + 1) % root.actions.length).forceActiveFocus()
            Keys.onReturnPressed: run()
            Keys.onEnterPressed: run()
            Keys.onSpacePressed: run()
            Keys.onEscapePressed: Visibilities.closeAll()

            Icon {
                anchors.centerIn: parent
                name: btn.modelData.icon
                size: 28
                color: btn.activeFocus ? Appearance.colors.onPrimary : Appearance.colors.text
            }

            StateLayer {
                radius: btn.radius
                onClicked: btn.run()
                onContainsMouseChanged: if (containsMouse) btn.forceActiveFocus()
            }

            Tooltip {
                x: -width - 14
                text: btn.modelData.label
                shown: btn.activeFocus
            }
        }
    }
}
