import QtQuick
import Quickshell.Bluetooth
import Quickshell.Services.UPower
import qs.components
import qs.config
import qs.services

// Status icons (Ethernet, Wi-Fi, Bluetooth, sound, battery, energy mode),
// each shown if picked in Settings → Tray. Scroll changes the volume,
// click opens the dashboard.
Pill {
    id: root

    required property string screenName
    readonly property var battery: UPower.displayDevice
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property list<string> picked: Settings.options.statusIcons

    readonly property var items: [
        {
            key: "ethernet",
            // A dead cable icon is noise while Wi-Fi carries the connection.
            shown: Network.ethernetConnected || !Network.wifiConnected,
            icon: Network.ethernetConnected ? "network-wired-activated-symbolic" : "network-wired-disconnected-symbolic",
            dim: !Network.ethernetConnected
        },
        {
            key: "wifi",
            shown: true,
            icon: Network.wifiIcon,
            dim: !Network.wifiConnected
        },
        {
            key: "bluetooth",
            shown: root.adapter !== null,
            icon: root.adapter?.enabled ? "network-bluetooth-symbolic" : "network-bluetooth-inactive-symbolic",
            dim: !(root.adapter?.enabled ?? false)
        },
        {
            key: "sound",
            shown: true,
            icon: Audio.icon,
            dim: false
        },
        {
            key: "battery",
            shown: root.battery?.isLaptopBattery ?? false,
            icon: root.battery?.iconName ?? "",
            dim: false
        },
        {
            key: "power",
            shown: true,
            icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "battery-profile-powersave-symbolic"
                : PowerProfiles.profile === PowerProfile.Performance ? "battery-profile-performance-symbolic"
                : "battery-profile-balanced-symbolic",
            dim: false
        },
    ].filter(i => i.shown && root.picked.includes(i.key))

    spacing: 8
    padding: 10
    visible: items.length > 0
    color: Visibilities.dashboard ? Appearance.colors.primaryContainer : Appearance.colors.surface

    Repeater {
        model: root.items

        Icon {
            required property var modelData
            anchors.horizontalCenter: parent.horizontalCenter
            name: modelData.icon
            size: 18
            color: modelData.dim ? Appearance.colors.textFaint : Appearance.colors.text
        }
    }

    StateLayer {
        parent: root
        radius: root.radius
        onClicked: Visibilities.toggle("dashboard", root.screenName)
        onWheel: wheel => Audio.setVolume(Audio.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
    }
}
