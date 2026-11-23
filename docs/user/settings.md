# Settings

Open them from the gear in the bar, or with `kshell ipc settings page <name>`.
Every change applies straight away and is saved to KShell's
`config/settings.json`, which is personal and kept out of git.

## Appearance

- **Blur the desktop behind apps**: blur and dim the wallpaper while an app has focus.
- **KShell OSD**: draw volume, brightness and other changes in the frame instead of Plasma's popup. Brightness gets one gauge per monitor.
- **Theme**: colours, window decorations and blur for the shell, Plasma and kitty.
- **Bar position**: left (default), top, right or bottom. A horizontal bar splits around the notch (top) or the launcher (bottom).
- **Show virtual desktops**: the desktop pills in the bar.
- **System icons**: Rounded, Outlined or Sharp, filled or not (droid-icons). Switching restarts the shell.
- **Colours**: *KDE scheme*, *Wallpaper* (Material 3 from the wallpaper) or *Theme accent*; the Material style (tonal spot, expressive, vibrant, ...); whether apps are recoloured too; accent, background and translucency for the KDE scheme.

## Notch

What the collapsed notch shows: the clock (time, date or both), what's playing,
and a dot for unread notifications.

## Tray

- **Status icons**: Ethernet, Wi-Fi, Bluetooth, sound, battery and energy mode.
- **App icons**: hide tray icons you don't want; *Show again* brings them back.

## Dock

Pinned apps in the bar, in order. Pins can also be changed by right-clicking
an app in the bar or the launcher.

## Wallpaper

- **Wallpaper folder**: where the picker looks (default `~/Pictures/Wallpapers`).
- **Displays**: the same wallpaper on every display, or one per display.
- **Fill** for each display: scaled and cropped, fit, stretch, centered or tiled. A portrait monitor usually wants *Fit*, with **Blur the empty space** around it.
- **Transition**: animated wallpaper changes, the effect (liquid, fade, wipe, circle, pixelate, dissolve, random) and its length.

## Clipboard

**Sync with phone** (through KDE Connect) and clearing the history. See
[Clipboard](clipboard.md).

## Displays

- **Arrangement**: drag the displays; they snap to each other's edges.
- For each display: enabled, primary, orientation (landscape, portrait and the flipped ones), resolution, refresh rate and scale. Risky changes revert after 15 seconds unless you keep them.
- **Multiple displays**: keep the sidebar and the notch to the primary display only, and choose where notification popups appear.

## About

droid's version and codename, with the release's art, and the Plasma and
Quickshell versions it runs on.
