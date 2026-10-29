import QtQuick
import QtQuick.Dialogs
import QtQuick.Effects
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import Quickshell.Services.UPower
import Quickshell.Widgets
import qs.components
import qs.config
import qs.services

// KShell settings: a normal app window with a page list on the left. Every
// control writes straight to Settings.options (config/settings.json), so
// changes apply as you make them.
FloatingWindow {
    id: root

    readonly property var pages: [
        { name: "Appearance", icon: "draw-brush-symbolic" },
        { name: "Notch", icon: "view-split-top-bottom-symbolic" },
        { name: "Tray", icon: "preferences-desktop-notification-symbolic" },
        { name: "Dock", icon: "view-pin-symbolic" },
        { name: "Wallpaper", icon: "preferences-desktop-wallpaper-symbolic" },
    ]

    title: "KShell Settings"
    implicitWidth: 820
    implicitHeight: 560
    minimumSize: Qt.size(640, 420)
    color: Appearance.base

    onVisibleChanged: if (!visible) Settings.open = false

    // ── Building blocks ──────────────────────────────────────────────

    // A labelled row with an optional description and a control on the right.
    component SettingRow: Rectangle {
        id: row
        property string label
        property string description
        property string icon
        default property alias control: slot.data

        width: parent?.width ?? 0
        implicitHeight: Math.max(64, text.implicitHeight + 28)
        radius: Appearance.sizes.radius
        color: Appearance.colors.surface

        Icon {
            id: rowIcon
            visible: row.icon !== ""
            anchors.left: parent.left
            anchors.leftMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            name: row.icon
            size: 24
        }

        Column {
            id: text
            anchors.left: rowIcon.visible ? rowIcon.right : parent.left
            anchors.leftMargin: 16
            anchors.right: slot.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            StyledText {
                width: parent.width
                text: row.label
                font.pointSize: Appearance.font.normal + 0.5
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                text: row.description
                color: Appearance.colors.textDim
                font.pointSize: Appearance.font.small
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
        }

        Row {
            id: slot
            anchors.right: parent.right
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }

    component PillButton: Rectangle {
        id: btn
        property string label
        property bool primary
        signal clicked

        implicitWidth: btnLabel.implicitWidth + 28
        implicitHeight: 34
        radius: height / 2
        color: primary ? Appearance.colors.primary : Appearance.colors.surfaceHigh

        StyledText {
            id: btnLabel
            anchors.centerIn: parent
            text: btn.label
            color: btn.primary ? Appearance.colors.onPrimary : Appearance.colors.text
        }
        StateLayer {
            tint: btn.primary ? Appearance.colors.onPrimary : Appearance.colors.text
            onClicked: btn.clicked()
        }
    }

    component Heading: StyledText {
        width: parent?.width ?? 0
        topPadding: 8
        font.pointSize: Appearance.font.large
        font.bold: true
    }

    component Hint: StyledText {
        width: parent?.width ?? 0
        color: Appearance.colors.textDim
        font.pointSize: Appearance.font.small
        wrapMode: Text.WordWrap
        elide: Text.ElideNone
    }

    // Like SettingRow, but its controls flow underneath the label (for
    // choices that need more room than the right-hand side of a row).
    component Block: Rectangle {
        id: block
        property string label
        property string description
        default property alias body: flow.data

        width: parent?.width ?? 0
        implicitHeight: col.implicitHeight + 32
        radius: Appearance.sizes.radius
        color: Appearance.colors.surface

        Column {
            id: col
            x: 16
            y: 16
            width: parent.width - 32
            spacing: 2

            StyledText {
                width: parent.width
                text: block.label
                font.pointSize: Appearance.font.normal + 0.5
            }
            StyledText {
                width: parent.width
                visible: text !== ""
                text: block.description
                color: Appearance.colors.textDim
                font.pointSize: Appearance.font.small
                wrapMode: Text.WordWrap
                elide: Text.ElideNone
            }
            Item { width: 1; height: 10 }
            Flow {
                id: flow
                width: parent.width
                spacing: 8
            }
        }
    }

    component Swatch: Rectangle {
        id: swatch
        property color swatchColor
        property bool selected
        signal picked

        width: 34
        height: 34
        radius: width / 2
        color: "transparent"
        border.width: selected ? 2 : 0
        border.color: Appearance.colors.text

        Rectangle {
            anchors.centerIn: parent
            width: 26
            height: 26
            radius: width / 2
            color: swatch.swatchColor
            border.width: 1
            border.color: Appearance.colors.outline
        }
        StateLayer {
            onClicked: swatch.picked()
        }
    }

    // ── Page list ────────────────────────────────────────────────────

    Rectangle {
        id: sidebar
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        width: 210
        color: Appearance.colors.surface

        Column {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 4

            StyledText {
                leftPadding: 10
                topPadding: 6
                bottomPadding: 12
                text: "Settings"
                font.pointSize: Appearance.font.xl
                font.bold: true
            }

            Repeater {
                model: root.pages

                Rectangle {
                    id: entry
                    required property var modelData
                    required property int index
                    readonly property bool current: Settings.page === index

                    width: parent.width
                    height: 42
                    radius: height / 2
                    color: current ? Appearance.colors.primaryContainer : "transparent"

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 14
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 12

                        Icon {
                            anchors.verticalCenter: parent.verticalCenter
                            name: entry.modelData.icon
                            size: 18
                            color: Appearance.colors.text
                        }
                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            text: entry.modelData.name
                            font.bold: entry.current
                        }
                    }

                    StateLayer {
                        onClicked: Settings.page = entry.index
                    }
                }
            }
        }
    }

    // ── Pages ────────────────────────────────────────────────────────

    Flickable {
        id: scroll
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.left: sidebar.right
        anchors.right: parent.right
        contentHeight: content.implicitHeight + 48
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: content
            x: 28
            y: 24
            width: scroll.width - 56
            spacing: 10

            StyledText {
                text: root.pages[Settings.page].name
                font.pointSize: Appearance.font.xl
                font.bold: true
                bottomPadding: 6
            }

            Loader {
                sourceComponent: [appearancePage, notchPage, trayPage, dockPage, wallpaperPage][Settings.page]
            }
        }
    }

    Component {
        id: appearancePage

        Column {
            width: content.width
            spacing: 10

            SettingRow {
                icon: "blurfx"
                label: "Blur the desktop behind apps"
                description: "Blurs and dims the wallpaper and desktop widgets while an app window has focus."
                StyledSwitch {
                    checked: Settings.options.backdropBlur
                    onToggled: Settings.options.backdropBlur = !checked
                }
            }

            SettingRow {
                icon: "preferences-desktop-theme-global"
                label: "Theme"
                description: "Colours, window decorations and blur for the shell, Plasma and kitty."
                PillButton {
                    label: "Choose theme…"
                    onClicked: Visibilities.show("themes", "")
                }
            }

            Heading { text: "Shell colours" }
            Hint {
                text: "Changes the bar, frame, notch and drawers only. Apps keep the theme's colours."
            }

            Block {
                label: "Accent"
                description: Settings.options.accentColor ? Settings.options.accentColor : "Following the theme"

                PillButton {
                    label: "Theme"
                    primary: !Settings.options.accentColor
                    onClicked: Settings.options.accentColor = ""
                }
                Repeater {
                    model: ["#3d7bfd", "#8c5cf6", "#e6609f", "#e5484d", "#f2802b", "#e8b32e", "#3fae6a", "#25a7a1"]
                    Swatch {
                        required property string modelData
                        swatchColor: modelData
                        selected: Settings.options.accentColor.toLowerCase() === modelData
                        onPicked: Settings.options.accentColor = modelData
                    }
                }
                PillButton {
                    label: "Custom…"
                    onClicked: accentDialog.open()
                }
            }

            Block {
                label: "Background"
                description: Settings.options.baseColor ? Settings.options.baseColor : "Following the theme"

                PillButton {
                    label: "Theme"
                    primary: !Settings.options.baseColor
                    onClicked: Settings.options.baseColor = ""
                }
                Repeater {
                    model: ["#1e1f22", "#151a2b", "#2b2724", "#0b0b0b", "#ecebe7"]
                    Swatch {
                        required property string modelData
                        swatchColor: modelData
                        selected: Settings.options.baseColor.toLowerCase() === modelData
                        onPicked: Settings.options.baseColor = modelData
                    }
                }
                PillButton {
                    label: "Custom…"
                    onClicked: baseDialog.open()
                }
            }

            SettingRow {
                id: opacityRow
                readonly property real min: 0.3
                enabled: Appearance.blur
                opacity: enabled ? 1 : 0.5
                icon: "blurfx"
                label: "Translucency"
                description: Appearance.blur ? `${Math.round(Settings.options.frameOpacity * 100)}% opaque`
                    : "Only used by blurred themes"

                StyledSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    implicitHeight: 22
                    value: (Settings.options.frameOpacity - opacityRow.min) / (1 - opacityRow.min)
                    onMoved: v => Settings.options.frameOpacity = Math.round((opacityRow.min + v * (1 - opacityRow.min)) * 100) / 100
                }
            }

            PillButton {
                visible: Settings.options.accentColor !== "" || Settings.options.baseColor !== "" || Settings.options.frameOpacity !== 0.62
                label: "Reset colours"
                onClicked: {
                    Settings.options.accentColor = "";
                    Settings.options.baseColor = "";
                    Settings.options.frameOpacity = 0.62;
                }
            }
        }
    }

    Component {
        id: notchPage

        Column {
            width: content.width
            spacing: 10

            // Live preview: the same pieces the notch shows, with sample
            // music when nothing is playing.
            Rectangle {
                width: parent.width
                height: 92
                radius: Appearance.sizes.radius
                color: Appearance.colors.surface

                Rectangle {
                    readonly property MprisPlayer player: Players.active
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: 0
                    width: preview.implicitWidth + 36
                    height: 36
                    color: Appearance.colors.frame
                    bottomLeftRadius: Appearance.sizes.rounding
                    bottomRightRadius: Appearance.sizes.rounding

                    Behavior on width {
                        NumberAnimation { duration: Appearance.anim.normal; easing.type: Easing.OutCubic }
                    }

                    Row {
                        id: preview
                        anchors.centerIn: parent
                        spacing: 10

                        StyledText {
                            anchors.verticalCenter: parent.verticalCenter
                            readonly property string time: Time.format(Time.use24h ? "hh:mm" : "h:mm AP")
                            readonly property string date: Time.format("ddd d MMM")
                            text: Settings.options.notchClock === "date" ? date
                                : Settings.options.notchClock === "datetime" ? `${date}  ·  ${time}`
                                : time
                            font.bold: true
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Settings.options.notchMedia
                            spacing: 8
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 4; height: 4; radius: 2; color: Appearance.colors.textFaint }
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "media-playback-start-symbolic"; size: 14; color: Appearance.colors.primary }
                            StyledText {
                                anchors.verticalCenter: parent.verticalCenter
                                readonly property var p: parent.parent.parent.player
                                width: Math.min(implicitWidth, 200)
                                text: (p?.isPlaying ? [p.trackTitle, p.trackArtist].filter(s => s).join(" — ") : "") || "Song — Artist"
                                color: Appearance.colors.textDim
                            }
                        }
                        Row {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: Settings.options.notchNotifications
                            spacing: 6
                            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 4; height: 4; radius: 2; color: Appearance.colors.textFaint }
                            Icon { anchors.verticalCenter: parent.verticalCenter; name: "notifications-symbolic"; size: 16; color: Appearance.colors.text }
                            StyledText { anchors.verticalCenter: parent.verticalCenter; text: Math.max(1, Notifs.list.length); font.bold: true; color: Appearance.colors.primary }
                        }
                    }
                }

                Hint {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 14
                    horizontalAlignment: Text.AlignHCenter
                    text: "Preview. Music and notifications only show in the notch when there are some."
                }
            }

            Block {
                label: "Clock"
                Repeater {
                    model: [
                        { id: "time", name: "Time" },
                        { id: "date", name: "Date" },
                        { id: "datetime", name: "Date + Time" },
                    ]
                    PillButton {
                        required property var modelData
                        label: modelData.name
                        primary: Settings.options.notchClock === modelData.id
                        onClicked: Settings.options.notchClock = modelData.id
                    }
                }
            }

            SettingRow {
                icon: "media-playback-start-symbolic"
                label: "Now playing"
                description: "Track, cover and a little equaliser while music plays."
                StyledSwitch {
                    checked: Settings.options.notchMedia
                    onToggled: Settings.options.notchMedia = !checked
                }
            }

            SettingRow {
                icon: "notifications-symbolic"
                label: "Notification indicator"
                description: "Unread count, and a muted bell while Do Not Disturb is on."
                StyledSwitch {
                    checked: Settings.options.notchNotifications
                    onToggled: Settings.options.notchNotifications = !checked
                }
            }
        }
    }

    Component {
        id: trayPage

        Column {
            width: content.width
            spacing: 10

            Heading { text: "Status icons" }
            Hint {
                text: "Shown at the bottom of the bar. Click them to open the dashboard."
                bottomPadding: 4
            }

            Repeater {
                model: {
                    const bat = UPower.displayDevice;
                    const hasBat = bat?.isLaptopBattery ?? false;
                    const bt = Bluetooth.defaultAdapter;
                    return [
                        { key: "ethernet", label: "Ethernet", icon: "network-wired-activated-symbolic",
                          note: Network.ethernetConnected ? "Connected" : "Not connected · hidden while Wi‑Fi is connected" },
                        { key: "wifi", label: "Wi‑Fi", icon: "network-wireless-symbolic",
                          note: !Network.wifiEnabled ? "Wi‑Fi is off" : Network.wifiConnected ? `Connected to ${Network.wifiName}` : "Not connected" },
                        { key: "bluetooth", label: "Bluetooth", icon: "network-bluetooth-symbolic",
                          note: bt ? (bt.enabled ? "On" : "Off") : "No Bluetooth adapter" },
                        { key: "sound", label: "Sound", icon: "audio-volume-high-symbolic",
                          note: "Scroll on the icons to change the volume" },
                        { key: "battery", label: "Battery", icon: "battery-full-symbolic",
                          note: hasBat ? `${Math.round(bat.percentage * 100)}%` : "No battery detected" },
                        { key: "power", label: "Energy mode", icon: "battery-profile-balanced-symbolic",
                          note: PowerProfile.toString(PowerProfiles.profile) },
                    ];
                }

                SettingRow {
                    id: statusRow
                    required property var modelData
                    readonly property bool on: Settings.options.statusIcons.includes(modelData.key)

                    icon: modelData.icon
                    label: modelData.label
                    description: modelData.note

                    StyledSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: statusRow.on
                        onToggled: {
                            const key = statusRow.modelData.key;
                            const order = ["ethernet", "wifi", "bluetooth", "sound", "battery", "power"];
                            const list = Settings.options.statusIcons.filter(k => k !== key);
                            if (!statusRow.on)
                                list.push(key);
                            Settings.options.statusIcons = order.filter(k => list.includes(k));
                        }
                    }
                }
            }

            Heading { text: "App icons" }
            Hint {
                text: "Tray icons from running apps. Apps only appear here while they're running."
                bottomPadding: 4
            }

            Repeater {
                model: SystemTray.items

                SettingRow {
                    id: trayRow
                    required property SystemTrayItem modelData
                    readonly property bool hidden: Settings.options.hiddenTray.includes(modelData.id)

                    label: modelData.title || modelData.tooltipTitle || modelData.id
                    description: modelData.id

                    IconImage {
                        anchors.verticalCenter: parent.verticalCenter
                        implicitSize: 22
                        source: {
                            const icon = trayRow.modelData.icon;
                            if (icon.includes("?path=")) {
                                const [name, path] = icon.split("?path=");
                                return `file://${path}/${name.slice(name.lastIndexOf("/") + 1)}`;
                            }
                            return icon;
                        }
                    }
                    Item { width: 10; height: 1 }
                    StyledSwitch {
                        anchors.verticalCenter: parent.verticalCenter
                        checked: !trayRow.hidden
                        onToggled: {
                            const id = trayRow.modelData.id;
                            const list = Settings.options.hiddenTray.filter(h => h !== id);
                            if (!trayRow.hidden)
                                list.push(id);
                            Settings.options.hiddenTray = list;
                        }
                    }
                }
            }

            // Hidden apps that aren't running right now, so they can be un-hidden.
            Repeater {
                model: Settings.options.hiddenTray.filter(id => !SystemTray.items.values.some(i => i.id === id))

                SettingRow {
                    required property string modelData
                    label: modelData
                    description: "Hidden · not running"
                    PillButton {
                        label: "Show again"
                        onClicked: Settings.options.hiddenTray = Settings.options.hiddenTray.filter(h => h !== modelData)
                    }
                }
            }

            Hint {
                visible: SystemTray.items.values.length === 0 && Settings.options.hiddenTray.length === 0
                text: "No apps with tray icons are running."
            }
        }
    }

    Component {
        id: dockPage

        Column {
            width: content.width
            spacing: 10

            Hint {
                text: "Pinned apps, top to bottom as they appear in the bar. Right-click an app in the launcher or the bar to pin it."
                bottomPadding: 4
            }

            Repeater {
                model: Dock.pinned

                SettingRow {
                    id: pinRow
                    required property string modelData
                    required property int index
                    readonly property var app: Dock.entry(modelData)

                    icon: app?.icon || "application-x-executable"
                    label: app?.name ?? modelData
                    description: app ? modelData : `${modelData} · no desktop entry found`

                    IconButton {
                        icon: "go-up-symbolic"
                        iconSize: 16
                        tooltip: ""
                        opacity: pinRow.index > 0 ? 1 : 0.3
                        enabled: pinRow.index > 0
                        onClicked: Dock.movePin(pinRow.index, pinRow.index - 1)
                    }
                    IconButton {
                        icon: "go-down-symbolic"
                        iconSize: 16
                        opacity: pinRow.index < Dock.pinned.length - 1 ? 1 : 0.3
                        enabled: pinRow.index < Dock.pinned.length - 1
                        onClicked: Dock.movePin(pinRow.index, pinRow.index + 1)
                    }
                    IconButton {
                        icon: "edit-delete-symbolic"
                        iconSize: 16
                        onClicked: Dock.togglePin(pinRow.modelData)
                    }
                }
            }

            Hint {
                visible: Dock.pinned.length === 0
                text: "Nothing is pinned."
            }
        }
    }

    Component {
        id: wallpaperPage

        Column {
            width: content.width
            spacing: 10

            SettingRow {
                icon: "folder-pictures"
                label: "Wallpaper folder"
                description: Wallpapers.dir
                PillButton {
                    label: "Open"
                    onClicked: Wallpapers.openFolder()
                }
                PillButton {
                    label: "Change…"
                    onClicked: folderDialog.open()
                }
                PillButton {
                    visible: Settings.options.wallpaperDir !== ""
                    label: "Reset"
                    onClicked: Settings.options.wallpaperDir = ""
                }
            }

            SettingRow {
                icon: "preferences-desktop-wallpaper"
                label: "Transition"
                description: "Animate wallpaper changes and previews. When off, they swap instantly."
                StyledSwitch {
                    checked: Settings.options.wallpaperTransition
                    onToggled: Settings.options.wallpaperTransition = !checked
                }
            }

            Block {
                enabled: Settings.options.wallpaperTransition
                opacity: enabled ? 1 : 0.5
                label: "Effect"
                description: "Random picks a different effect each time."

                Repeater {
                    model: [
                        { id: "liquid", name: "Liquid" },
                        { id: "fade", name: "Fade" },
                        { id: "wipe", name: "Wipe" },
                        { id: "circle", name: "Circle" },
                        { id: "pixelate", name: "Pixelate" },
                        { id: "dissolve", name: "Dissolve" },
                        { id: "random", name: "Random" },
                    ]
                    PillButton {
                        required property var modelData
                        label: modelData.name
                        primary: Settings.options.transitionEffect === modelData.id
                        onClicked: Settings.options.transitionEffect = modelData.id
                    }
                }
            }

            // Live preview of the chosen effect, looping between the current
            // wallpaper and the next one in the folder.
            Rectangle {
                id: fxPreview
                readonly property list<string> effects: ["liquid", "fade", "wipe", "circle", "pixelate", "dissolve"]
                readonly property string chosen: Settings.options.transitionEffect
                readonly property string next: {
                    const f = Wallpapers.files;
                    return f.length ? f[(f.indexOf(Wallpapers.current) + 1) % f.length] : "";
                }
                // Re-rolled after each run while "random" is chosen.
                property string randomEffect: effects[Math.floor(Math.random() * effects.length)]
                readonly property string effect: chosen === "random" ? randomEffect
                    : effects.includes(chosen) ? chosen : "liquid"
                // Which image is "from"; flipped after each run so the loop
                // continues from what's on screen without reloading anything.
                property bool flip: false

                // Show a newly picked effect straight away.
                onEffectChanged: {
                    progress = 0;
                    play.restart();
                }

                width: parent.width
                height: Math.round(width * 9 / 16 * 0.62)
                radius: Appearance.sizes.radius
                color: Appearance.colors.surface
                visible: Settings.options.wallpaperTransition && Wallpapers.files.length > 1

                Image {
                    id: thumbA
                    visible: false
                    source: Wallpapers.current ? Wallpapers.url(Wallpapers.current) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(640, 360)
                    asynchronous: true
                }
                Image {
                    id: thumbB
                    visible: false
                    source: fxPreview.next ? Wallpapers.url(fxPreview.next) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(640, 360)
                    asynchronous: true
                }

                // One shader per direction (A→B, B→A), each with fixed
                // textures; the loop alternates which one is shown.
                component ThumbFx: ShaderEffect {
                    property Image fromTex
                    property Image toTex
                    property real progress: fxPreview.progress
                    property vector2d resolution: Qt.vector2d(width, height)
                    property vector2d fromSize: Qt.vector2d(fromTex.implicitWidth, fromTex.implicitHeight)
                    property vector2d toSize: Qt.vector2d(toTex.implicitWidth, toTex.implicitHeight)

                    anchors.fill: parent
                    fragmentShader: Qt.resolvedUrl(`../../shaders/${fxPreview.effect}.frag.qsb`)
                }

                property real progress: 0

                Item {
                    id: stage
                    anchors.fill: parent
                    anchors.margins: 8
                    visible: thumbA.status === Image.Ready && thumbB.status === Image.Ready

                    layer.enabled: true
                    layer.effect: MultiEffect {
                        maskEnabled: true
                        maskSource: thumbMask
                        maskThresholdMin: 0.5
                        maskSpreadAtMin: 1
                    }

                    ThumbFx {
                        visible: !fxPreview.flip
                        fromTex: thumbA
                        toTex: thumbB
                    }
                    ThumbFx {
                        visible: fxPreview.flip
                        fromTex: thumbB
                        toTex: thumbA
                    }

                    StyledText {
                        anchors.left: parent.left
                        anchors.bottom: parent.bottom
                        anchors.margins: 10
                        text: fxPreview.effect.charAt(0).toUpperCase() + fxPreview.effect.slice(1)
                            + (fxPreview.chosen === "random" ? "  ·  random" : "")
                        color: "white"
                        font.bold: true
                        style: Text.Outline
                        styleColor: "#80000000"
                    }
                }

                Rectangle {
                    id: thumbMask
                    anchors.fill: stage
                    radius: Appearance.sizes.radiusSmall
                    visible: false
                    layer.enabled: true
                }

                SequentialAnimation {
                    id: play
                    running: fxPreview.visible && stage.visible
                    loops: Animation.Infinite

                    NumberAnimation {
                        target: fxPreview
                        property: "progress"
                        from: 0
                        to: 1
                        duration: Settings.options.transitionDuration
                        easing.type: Easing.InOutCubic
                    }
                    PauseAnimation { duration: 900 }
                    ScriptAction {
                        script: {
                            // The new image is fully shown: run the other direction next.
                            fxPreview.flip = !fxPreview.flip;
                            fxPreview.progress = 0;
                            if (fxPreview.chosen === "random")
                                fxPreview.randomEffect = fxPreview.effects[Math.floor(Math.random() * fxPreview.effects.length)];
                        }
                    }
                }
            }

            SettingRow {
                id: durationRow
                readonly property real min: 800
                readonly property real max: 5000
                enabled: Settings.options.wallpaperTransition
                opacity: enabled ? 1 : 0.5
                icon: "chronometer"
                label: "Transition length"
                description: `${(Settings.options.transitionDuration / 1000).toFixed(1)} s`

                StyledSlider {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 220
                    implicitHeight: 22
                    value: (Settings.options.transitionDuration - durationRow.min) / (durationRow.max - durationRow.min)
                    onMoved: v => Settings.options.transitionDuration = Math.round((durationRow.min + v * (durationRow.max - durationRow.min)) / 100) * 100
                }
            }
        }
    }

    ColorDialog {
        id: accentDialog
        title: "Accent colour"
        selectedColor: Appearance.accent
        onAccepted: Settings.options.accentColor = selectedColor.toString()
    }

    ColorDialog {
        id: baseDialog
        title: "Background colour"
        selectedColor: Appearance.base
        onAccepted: Settings.options.baseColor = selectedColor.toString()
    }

    FolderDialog {
        id: folderDialog
        title: "Choose the wallpaper folder"
        currentFolder: Wallpapers.url(Wallpapers.dir)
        onAccepted: Settings.options.wallpaperDir = decodeURIComponent(selectedFolder.toString().replace(/^file:\/\//, ""))
    }
}
