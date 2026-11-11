import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// Quick settings, the control center's middle column (after shoji-bar-4's
// panel): a greeting, wavy volume / brightness sliders, toggle tiles, a
// battery card on laptops, and pages for Internet, Bluetooth and Sound that
// slide in over the tiles.
Item {
    id: root

    property bool open
    // "" (tiles) | network | bluetooth | sound
    property string page: ""
    // Last page shown, kept while sliding back out.
    property string shownPage: ""
    onPageChanged: if (page) shownPage = page
    onOpenChanged: if (!open) page = ""

    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var battery: UPower.displayDevice
    readonly property bool hasBattery: battery?.isLaptopBattery ?? false
    readonly property var theme: Themes.list.find(t => t.id === Themes.target) ?? null

    Component.onCompleted: User.users++
    Component.onDestruction: User.users--

    // Shared-axis X between the tiles and a page.
    Spring {
        id: slide
        target: root.page ? 1 : 0
        preset: Appearance.spring.defaultSpatial
    }

    // ── Building blocks ──────────────────────────────────────────────

    // A toggle tile. Clicking toggles; tiles with a page get a chevron that
    // opens it. On, the tile turns primary and its corners tighten (M3
    // Expressive shape change).
    component Tile: Item {
        id: tile
        property string icon
        property string label
        property string sub
        property bool on
        property string page: ""
        signal toggled

        width: (parent.width - 8) / 2
        height: 56

        Spring {
            id: morph
            target: tile.on ? 1 : 0
            preset: Appearance.spring.fastSpatial
        }

        Rectangle {
            id: bg
            anchors.fill: parent
            radius: (1 - morph.value) * height / 2 + morph.value * Appearance.sizes.radius
            color: tile.on ? Appearance.colors.primary : Appearance.colors.surfaceHigh
            Behavior on color { ColorAnimation { duration: Appearance.anim.fast } }

            StateLayer {
                anchors.rightMargin: tile.page ? 40 : 0
                radius: bg.radius
                tint: tile.on ? Appearance.colors.onPrimary : Appearance.colors.text
                onClicked: tile.toggled()
            }
        }

        Icon {
            id: tileIcon
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: tile.icon
            size: 20
            color: tile.on ? Appearance.colors.onPrimary : Appearance.colors.text
        }

        Column {
            anchors.left: tileIcon.right
            anchors.leftMargin: 10
            anchors.right: chevron.visible ? chevron.left : parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            StyledText {
                width: parent.width
                text: tile.label
                font.bold: true
                color: tile.on ? Appearance.colors.onPrimary : Appearance.colors.text
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                text: tile.sub
                font.pointSize: Appearance.font.small
                color: tile.on ? Qt.alpha(Appearance.colors.onPrimary, 0.8) : Appearance.colors.textDim
            }
        }

        Rectangle {
            id: chevron
            visible: tile.page !== ""
            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            width: 34
            height: 44
            radius: 17
            color: "transparent"

            Icon {
                anchors.centerIn: parent
                name: "go-next-symbolic"
                size: 16
                color: tile.on ? Appearance.colors.onPrimary : Appearance.colors.textDim
            }
            StateLayer {
                tint: tile.on ? Appearance.colors.onPrimary : Appearance.colors.text
                onClicked: root.page = tile.page
            }
        }
    }

    // A row in a page list: icon, title, detail, optional trailing check.
    component ListRow: Rectangle {
        id: lrow
        property string icon
        property string title
        property string detail
        property bool selected
        property bool busy
        signal clicked

        width: parent?.width ?? 0
        height: 48
        radius: Appearance.sizes.radiusSmall
        color: selected ? Appearance.colors.secondaryContainer : "transparent"

        Icon {
            id: lrIcon
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            name: lrow.icon
            size: 20
            color: lrow.selected ? Appearance.colors.onSecondaryContainer : Appearance.colors.text
        }
        Column {
            anchors.left: lrIcon.right
            anchors.leftMargin: 12
            anchors.right: check.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            StyledText {
                width: parent.width
                text: lrow.title
                color: lrow.selected ? Appearance.colors.onSecondaryContainer : Appearance.colors.text
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                text: lrow.detail
                font.pointSize: Appearance.font.small
                color: Appearance.colors.textDim
            }
        }
        Icon {
            id: check
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            name: lrow.busy ? "view-refresh-symbolic" : "object-select-symbolic"
            size: 16
            visible: lrow.selected || lrow.busy
            color: Appearance.colors.onSecondaryContainer
        }
        StateLayer {
            onClicked: lrow.clicked()
        }
    }

    component PageHeader: Item {
        id: ph
        property string title
        default property alias trailing: trail.data
        width: parent?.width ?? 0
        height: 40

        IconButton {
            id: back
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            icon: "go-previous-symbolic"
            iconSize: 18
            onClicked: root.page = ""
        }
        StyledText {
            anchors.left: back.right
            anchors.leftMargin: 6
            anchors.verticalCenter: parent.verticalCenter
            text: ph.title
            font.pointSize: Appearance.font.large
            font.bold: true
        }
        Row {
            id: trail
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }

    component SubHeading: StyledText {
        width: parent?.width ?? 0
        topPadding: 6
        bottomPadding: 2
        font.pointSize: Appearance.font.small
        font.bold: true
        color: Appearance.colors.primary
    }

    component FooterLink: Rectangle {
        id: fl
        property string label
        property list<string> command
        width: fll.implicitWidth + 28
        height: 34
        radius: 17
        color: Appearance.colors.surfaceHigh
        StyledText {
            id: fll
            anchors.centerIn: parent
            text: fl.label
        }
        StateLayer {
            onClicked: {
                Visibilities.closeAll();
                Quickshell.execDetached(fl.command);
            }
        }
    }

    // ── Tiles ────────────────────────────────────────────────────────
    Column {
        id: main
        width: parent.width
        spacing: 12
        x: -40 * slide.value
        opacity: Math.max(0, 1 - slide.value * 1.6)
        visible: opacity > 0

        // Greeting
        Item {
            width: parent.width
            height: 44

            ClippingRectangle {
                id: avatar
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: 40
                height: 40
                radius: 20
                color: Appearance.colors.primaryContainer

                Image {
                    id: face
                    anchors.fill: parent
                    source: "file://" + User.avatar
                    sourceSize: Qt.size(80, 80)
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    onStatusChanged: if (status === Image.Error && source.toString() !== "file://" + User.faceFallback)
                        source = "file://" + User.faceFallback
                }
                StyledText {
                    anchors.centerIn: parent
                    visible: face.status !== Image.Ready
                    text: User.firstName.charAt(0).toUpperCase()
                    font.pointSize: Appearance.font.large
                    font.bold: true
                    color: Appearance.colors.onPrimaryContainer
                }
            }

            Column {
                anchors.left: avatar.right
                anchors.leftMargin: 12
                anchors.right: actions.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    text: `${User.greeting}, ${User.firstName}`
                    font.bold: true
                    font.pointSize: Appearance.font.normal + 0.5
                }
                StyledText {
                    width: parent.width
                    text: `Up ${User.uptime}`
                    font.pointSize: Appearance.font.small
                    color: Appearance.colors.textDim
                }
            }

            Row {
                id: actions
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                IconButton {
                    icon: "configure-symbolic"
                    iconSize: 18
                    tooltip: "System Settings"
                    onClicked: {
                        Visibilities.closeAll();
                        Quickshell.execDetached(["systemsettings"]);
                    }
                }
                IconButton {
                    icon: "system-shutdown-symbolic"
                    iconSize: 18
                    tooltip: "Power"
                    onClicked: Visibilities.show("session", Visibilities.screen)
                }
            }
        }

        // Sliders
        Item {
            width: parent.width
            height: 32

            WavySlider {
                anchors.left: parent.left
                anchors.right: soundPage.left
                anchors.rightMargin: 6
                height: parent.height
                icon: Audio.icon
                value: Audio.muted ? 0 : Math.min(1, Audio.volume)
                onMoved: v => Audio.setVolume(v)
                onIconClicked: Audio.toggleMute()
            }
            IconButton {
                id: soundPage
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                icon: "go-next-symbolic"
                iconSize: 16
                tooltip: "Sound devices"
                onClicked: root.page = "sound"
            }
        }

        WavySlider {
            width: parent.width - 38
            visible: Brightness.available
            icon: Brightness.icon
            value: Brightness.value
            onMoved: v => Brightness.set(v)
        }

        // Tiles
        Flow {
            width: parent.width
            spacing: 8

            Tile {
                // -activated isn't in every icon theme (e.g. Tela).
                icon: Network.type === "ethernet" ? "network-wired-symbolic" : Network.icon
                label: "Internet"
                sub: Network.type === "ethernet" ? "Ethernet" : Network.type === "wifi" ? Network.name
                    : Network.wifiEnabled ? "Not connected" : "Off"
                on: Network.type !== "none"
                page: "network"
                onToggled: Network.toggleWifi()
            }
            Tile {
                visible: root.adapter !== null
                icon: "network-bluetooth-symbolic"
                label: "Bluetooth"
                sub: {
                    if (!(root.adapter?.enabled ?? false))
                        return "Off";
                    const c = (root.adapter?.devices.values ?? []).filter(d => d.connected);
                    return c.length === 1 ? c[0].name : c.length > 1 ? `${c.length} devices` : "On";
                }
                on: root.adapter?.enabled ?? false
                page: "bluetooth"
                onToggled: root.adapter.enabled = !root.adapter.enabled
            }
            Tile {
                icon: "weather-clear-night-symbolic"
                label: "Dark theme"
                sub: root.theme?.name ?? ""
                on: root.theme?.dark ?? true
                onToggled: Themes.toggleDark()
            }
            Tile {
                icon: Visibilities.dnd ? "notifications-disabled-symbolic" : "notifications-symbolic"
                label: "Do not disturb"
                sub: Visibilities.dnd ? "On" : "Off"
                on: Visibilities.dnd
                onToggled: Visibilities.dnd = !Visibilities.dnd
            }
            Tile {
                icon: PowerProfiles.profile === PowerProfile.PowerSaver ? "battery-profile-powersave-symbolic"
                    : PowerProfiles.profile === PowerProfile.Performance ? "battery-profile-performance-symbolic"
                    : "battery-profile-balanced-symbolic"
                label: "Power mode"
                sub: PowerProfile.toString(PowerProfiles.profile)
                on: PowerProfiles.profile !== PowerProfile.Balanced
                onToggled: {
                    const order = [PowerProfile.PowerSaver, PowerProfile.Balanced];
                    if (PowerProfiles.hasPerformanceProfile)
                        order.push(PowerProfile.Performance);
                    PowerProfiles.profile = order[(order.indexOf(PowerProfiles.profile) + 1) % order.length];
                }
            }
            Tile {
                icon: Audio.micMuted ? "microphone-sensitivity-muted-symbolic" : "microphone-sensitivity-high-symbolic"
                label: "Microphone"
                sub: !Audio.hasMic ? "None found" : Audio.micMuted ? "Muted" : "On"
                on: Audio.hasMic && !Audio.micMuted
                onToggled: Audio.toggleMic()
            }
        }

        // Battery (laptops)
        Rectangle {
            id: batCard
            visible: root.hasBattery
            width: parent.width
            height: 60
            radius: Appearance.sizes.radius
            color: Appearance.colors.surfaceHigh

            property int cycles: -1
            FileView {
                path: root.hasBattery ? `/sys/class/power_supply/${root.battery.nativePath.split("/").pop()}/cycle_count` : ""
                printErrors: false
                onLoaded: batCard.cycles = parseInt(text())
            }

            Icon {
                id: batIcon
                anchors.left: parent.left
                anchors.leftMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                name: root.battery?.iconName ?? "battery-symbolic"
                size: 26
                color: Appearance.colors.text
            }
            Column {
                anchors.left: batIcon.right
                anchors.leftMargin: 12
                anchors.right: parent.right
                anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter

                StyledText {
                    width: parent.width
                    readonly property real secs: root.battery?.state === UPowerDeviceState.Charging
                        ? root.battery.timeToFull : root.battery?.timeToEmpty ?? 0
                    text: `${Math.round((root.battery?.percentage ?? 0) * 100)}%` + (secs > 0
                        ? ` · ${Math.floor(secs / 3600)}h ${Math.floor(secs % 3600 / 60)}m ${root.battery.state === UPowerDeviceState.Charging ? "to full" : "left"}` : "")
                    font.bold: true
                }
                StyledText {
                    width: parent.width
                    text: [root.battery?.healthSupported ? `Health ${Math.round(root.battery.healthPercentage)}%` : "",
                        batCard.cycles >= 0 ? `${batCard.cycles} cycles` : ""].filter(s => s).join(" · ")
                    font.pointSize: Appearance.font.small
                    color: Appearance.colors.textDim
                }
            }
        }
    }

    // ── Pages ────────────────────────────────────────────────────────
    Loader {
        id: pageLoader
        width: parent.width
        height: parent.height
        x: 40 * (1 - slide.value)
        opacity: Math.max(0, slide.value * 1.6 - 0.6)
        visible: opacity > 0
        active: root.shownPage !== "" && slide.value > 0
        sourceComponent: ({ network: networkPage, bluetooth: bluetoothPage, sound: soundPageC })[root.shownPage] ?? null
    }

    Component {
        id: networkPage

        Column {
            id: netPage
            spacing: 6
            property var networks: []

            Process {
                id: scan
                running: true
                command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const seen = {};
                        netPage.networks = text.trim().split("\n").filter(l => l).map(l => {
                            const f = l.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"));
                            return { active: f[0] === "*", ssid: f[1], signal: parseInt(f[2]) || 0, secure: !!f[3] };
                        }).filter(n => n.ssid && !seen[n.ssid] && (seen[n.ssid] = true))
                          .sort((a, b) => b.active - a.active || b.signal - a.signal);
                    }
                }
            }

            PageHeader {
                title: "Internet"
                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Network.wifiEnabled
                    onToggled: Network.toggleWifi()
                }
            }

            ListRow {
                visible: Network.ethernetConnected
                icon: "network-wired-activated-symbolic"
                title: "Ethernet"
                detail: Network.type === "ethernet" ? Network.name : "Connected"
                selected: true
            }

            SubHeading { text: "Wi-Fi" }

            StyledText {
                width: parent.width
                visible: !Network.wifiEnabled || netPage.networks.length === 0
                text: !Network.wifiEnabled ? "Wi-Fi is off" : scan.running ? "Looking for networks…" : "No networks found"
                color: Appearance.colors.textDim
                leftPadding: 10
            }

            ListView {
                width: parent.width
                height: Math.min(contentHeight, 200)
                visible: Network.wifiEnabled
                clip: true
                spacing: 2
                model: netPage.networks
                delegate: ListRow {
                    required property var modelData
                    width: ListView.view.width
                    icon: modelData.signal >= 80 ? "network-wireless-signal-excellent-symbolic"
                        : modelData.signal >= 55 ? "network-wireless-signal-good-symbolic"
                        : modelData.signal >= 30 ? "network-wireless-signal-ok-symbolic" : "network-wireless-signal-weak-symbolic"
                    title: modelData.ssid
                    detail: (modelData.secure ? "Secured" : "Open") + (modelData.active ? " · Connected" : "")
                    selected: modelData.active
                    // Saved and open networks connect directly; new secured
                    // ones need a password, so they go to System Settings.
                    onClicked: Quickshell.execDetached(["sh", "-c",
                        'nmcli dev wifi connect "$1" || kcmshell6 kcm_networkmanagement', "sh", modelData.ssid])
                }
            }

            Item { width: 1; height: 4 }
            FooterLink {
                label: "Network settings"
                command: ["kcmshell6", "kcm_networkmanagement"]
            }
        }
    }

    Component {
        id: bluetoothPage

        Column {
            spacing: 6

            PageHeader {
                title: "Bluetooth"
                IconButton {
                    visible: root.adapter?.enabled ?? false
                    icon: "view-refresh-symbolic"
                    iconSize: 16
                    active: root.adapter?.discovering ?? false
                    tooltip: "Search for devices"
                    onClicked: root.adapter.discovering = !root.adapter.discovering
                }
                StyledSwitch {
                    anchors.verticalCenter: parent.verticalCenter
                    checked: root.adapter?.enabled ?? false
                    onToggled: root.adapter.enabled = !root.adapter.enabled
                }
            }

            ListView {
                width: parent.width
                height: Math.min(contentHeight, 250)
                visible: root.adapter?.enabled ?? false
                clip: true
                spacing: 2
                model: [...(root.adapter?.devices.values ?? [])]
                    .filter(d => d.paired || d.name)
                    .sort((a, b) => b.connected - a.connected || b.paired - a.paired)
                delegate: ListRow {
                    required property var modelData
                    width: ListView.view.width
                    icon: modelData.icon || "network-bluetooth-symbolic"
                    title: modelData.name || modelData.address
                    detail: modelData.connected ? (modelData.batteryAvailable ? `Connected · ${Math.round(modelData.battery * 100)}%` : "Connected")
                        : modelData.paired ? "Paired" : "Available"
                    selected: modelData.connected
                    busy: modelData.state === BluetoothDeviceState.Connecting || modelData.pairing
                    onClicked: {
                        if (modelData.connected)
                            modelData.disconnect();
                        else if (modelData.paired)
                            modelData.connect();
                        else
                            modelData.pair();
                    }
                }
            }

            StyledText {
                visible: !(root.adapter?.enabled ?? false)
                text: "Bluetooth is off"
                color: Appearance.colors.textDim
                leftPadding: 10
            }

            Item { width: 1; height: 4 }
            FooterLink {
                label: "Bluetooth settings"
                command: ["kcmshell6", "kcm_bluetooth"]
            }
        }
    }

    Component {
        id: soundPageC

        Column {
            spacing: 6

            PageHeader { title: "Sound" }

            SubHeading { text: "Output" }
            Repeater {
                model: Audio.sinks
                ListRow {
                    required property var modelData
                    icon: "audio-speakers-symbolic"
                    title: modelData.description || modelData.nickname || modelData.name
                    selected: modelData === Audio.sink
                    onClicked: Audio.setSink(modelData)
                }
            }

            SubHeading { text: "Input" }
            Repeater {
                model: Audio.sources
                ListRow {
                    required property var modelData
                    icon: "microphone-sensitivity-high-symbolic"
                    title: modelData.description || modelData.nickname || modelData.name
                    selected: modelData === Audio.source
                    onClicked: Audio.setSource(modelData)
                }
            }

            Item { width: 1; height: 4 }
            FooterLink {
                label: "Sound settings"
                command: ["kcmshell6", "kcm_pulseaudio"]
            }
        }
    }
}
