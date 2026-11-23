# Repository layout

```text
droid/
├── droid.toml            release (version, codename), packages, links, fonts
├── RELEASES.md           what each release brought, by codename
├── justfile              tasks: `just` lists them
├── lefthook.yml          git hooks
├── install.sh, install.py, installer/   the installer
├── scripts/              check_manifest.py, commit-msg.main.kts, release.main.kts
├── assets/               branding: droid head, codename art
├── docs/, mkdocs.yml     this portal
├── apps/                 Kotlin apps (Gradle, Kotlin DSL)
│   └── common/           DroidTheme (KShell's colours, Google Sans), KShell IPC
└── home/                 linked into $HOME by ./install.py link
    ├── .config/quickshell/kshell/
    │   ├── shell.qml     entry point
    │   ├── config/       Settings.qml, Appearance.qml, themes.json (settings.json and pinned.json are personal, not in git)
    │   ├── services/     singletons: Displays, Wallpapers, Brightness, Apps, Bridge, ...
    │   ├── modules/      ScreenShell, bar/, drawers/, settings/, notifications/
    │   ├── components/   Pill, Drawer, Spring, Icon, sliders, ...
    │   ├── shaders/      wallpaper transitions (.frag + compiled .qsb)
    │   ├── bridge/       bridge.js (KWin script)
    │   └── daemon/       kshelld (Rust)
    ├── .local/bin/kshell the `kshell` command
    └── .config/{zsh,kitty,fontconfig,...}
```
