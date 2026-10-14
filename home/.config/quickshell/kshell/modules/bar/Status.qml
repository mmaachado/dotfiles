import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.components
import qs.config
import qs.services

// Network / Bluetooth / volume / battery. Scroll changes the volume,
// click opens the dashboard.
Pill {
    id: root

    required property string screenName
    readonly property var battery: UPower.displayDevice
    readonly property var adapter: Bluetooth.defaultAdapter

    spacing: 8
    padding: 10
    color: Visibilities.dashboard ? Appearance.colors.primaryContainer : Appearance.colors.surface

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: Network.icon
        size: 18
        color: Appearance.colors.text
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.adapter !== null
        name: root.adapter?.enabled ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic"
        size: 18
        color: root.adapter?.enabled ? Appearance.colors.text : Appearance.colors.textFaint
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        name: Audio.icon
        size: 18
        color: Appearance.colors.text
    }

    Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        visible: root.battery?.isLaptopBattery ?? false
        name: root.battery?.iconName ?? ""
        size: 18
        color: Appearance.colors.text
    }

    StateLayer {
        parent: root
        radius: root.radius
        onClicked: Visibilities.toggle("dashboard", root.screenName)
        onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
