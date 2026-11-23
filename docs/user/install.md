# Install

droid runs on **Arch Linux** with **KDE Plasma 6 on Wayland**.

```sh
git clone https://github.com/mmaachado/droid.git ~/droid
cd ~/droid
./install.sh all
```

`install.sh` installs Python, Typer and Rich if they're missing, then runs
`install.py all`, which goes through every step below and asks before each
one. Every command that changes something takes `--dry-run`.

| Step | Command | What it does |
| --- | --- | --- |
| Check | `./install.py check` | Report packages, fonts, links, login shell and KShell (changes nothing) |
| Packages | `./install.py packages [-g core -g kshell] [--optional]` | Install missing packages (pacman; AUR through paru/yay; some tools through uv) |
| Links | `./install.py link [--force]` | Symlink `home/*` into `$HOME`; anything in the way goes to `~/.local/state/droid/backup/<time>/` |
| Fonts | `./install.py fonts [--no-apply]` | Fetch Google Sans Flex (pinned and checksum-verified) and make Google Sans the desktop font |
| Shell | `./install.py shell` | Make zsh the login shell |
| KShell | `./install.py kshell enable` | Replace the Plasma panels with KShell |

The package groups, linked files and fonts are listed in
[`droid.toml`](https://github.com/mmaachado/droid/blob/master/droid.toml).

## System icons

```sh
kshell icons on               # Rounded, filled (Android's look)
kshell icons on sharp outline # any style: rounded, outlined or sharp; filled or outline
```

This installs [droid-icons](https://github.com/mmaachado/droid-icons), which
draws the system icons (Wi-Fi, battery, volume, ...) with Material Symbols
and keeps Tela-circle for app icons. Settings → Appearance switches styles too.

## Undo

```sh
./install.py kshell disable     # the Plasma panels and default shortcuts come back
./install.py unlink --restore   # put back the files that were replaced
kshell fonts off                # Plasma's default fonts
kshell icons off                # plain Tela-circle
```
