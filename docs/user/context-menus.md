# Context menus

Right-click menus look the same everywhere, styled after VSCode's: a rounded
panel with a thin border, plain text rows, shortcuts dimmed on the right, thin
separators, and the accent colour behind the row under the pointer. They take
the colours of the current theme and change with it.

| Where | How |
| --- | --- |
| KShell | Its own menus: tray icons, the task bar, the launcher and clipboard history |
| Qt and KDE apps, the Plasma desktop | A Kvantum theme kshelld generates for each KShell theme |
| GTK 3 and GTK 4 apps (libadwaita too) | `~/.config/gtk-3.0` and `gtk-4.0/kshell-menus.css`, imported from `gtk.css` |
| Firefox | `chrome/kshell-menus.css` in each profile, imported from `userChrome.css` |

## In KShell

- **Tray icons**: right-click for the app's menu, drawn by KShell.
- **Task bar**: right-click an app for *New Window*, *Pin to Bar* / *Unpin
  from Bar* and *Close Window*. Middle click still opens a new window.
- **Launcher**: right-click an app to open it or pin it to the bar.
- **Clipboard history**: right-click an entry to copy it, pin it, send it to
  your phone or delete it.

Menus work from the keyboard too: ↑/↓ to move, Enter to pick, → and ← for
submenus, Esc to close.

## In apps

Applying a theme (Meta+Shift+T) writes everything. Apps pick it up as follows:

- **Qt and KDE apps** switch at once. The app style is now always Kvantum
  (it was Breeze for themes without blur). Without Kvantum installed, apps
  keep Breeze and Breeze's menus.
- **GTK apps** when they restart.
- **Firefox** when it restarts. kshelld turns on
  `toolkit.legacyUserProfileCustomizations.stylesheets` in the profile's
  `user.js`, which Firefox needs before it reads `userChrome.css`.

Your own rules in `gtk.css` and `userChrome.css` stay: kshelld only adds its
`@import` line, and only rewrites its own `kshell-menus.css` files.

To go back to the old look in one toolkit, delete the `@import` line for
`kshell-menus.css` (GTK, Firefox), or pick another style in System Settings →
Colours & Themes → Application Style (Qt). Applying a KShell theme again
restores them.
