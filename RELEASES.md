# droid releases

Each major version of droid takes the next Android dessert as its codename,
in Android's order: 1.x is Cupcake, 2.x will be Donut, then Eclair, Froyo,
and so on. Minor and patch releases keep their major version's codename. The
version and codename live in [`droid.toml`](droid.toml).

## 1.x Cupcake

<img src="assets/droid_cupcake.svg" alt="Cupcake" width="120" align="right">

### 1.1.0

- **Google Sans everywhere**: Google Sans Flex for the interface and Google
  Sans Code for monospace, set for KDE, GTK, fontconfig, kitty and KShell
  (`kshell fonts on|off`).
- **System icon styles**: Rounded, Outlined or Sharp, filled or not, from
  Settings → Appearance (droid-icons now ships all six).
- **Bar position**: left (default), top, right or bottom. Horizontal bars
  split around the notch or the launcher. The virtual desktops in the bar can
  be hidden.
- **Brightness per monitor**: a slider for each monitor in Quick Settings,
  and an OSD gauge for each when the brightness keys are pressed.
- **Launcher** leaves out apps that aren't installed any more (stale
  Flatpak launchers, missing programs).
- **Personal settings stay out of git**: settings.json and pinned.json are
  ignored; new installs start from the defaults.
- Settings → About shows the release art.

### 1.0.0

The first release, after the dotfiles became droid.

- KShell: the bar, notch and dashboard, launcher, wallpaper/theme/clipboard
  pickers, notifications, OSD and settings, all on top of Plasma.
- Material 3 colours from the wallpaper or the theme, with spring motion.
- Multiple monitors: a Displays settings page (arrangement, primary,
  orientation, resolution, refresh rate, scale) and per-display wallpapers
  with a fill mode each.
- Android-style system icons from droid-icons over Tela-circle.
- `droid.toml`, the installer (`install.py`), CI, the release workflow and
  issue/PR templates.

---

The Android robot is reproduced or modified from work created and shared by
Google and used according to terms described in the Creative Commons 3.0
Attribution License. droid isn't affiliated with or endorsed by Google.
