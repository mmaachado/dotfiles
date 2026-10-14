# dotfiles — KDE Plasma + Quickshell

A desktop that keeps **KDE Plasma** underneath (KWin, session, settings, power,
devices, wallpaper, desktop widgets) and replaces its panels with **KShell**, a
Caelestia-style shell built with [Quickshell](https://quickshell.org). Plus the
zsh setup that goes with it. See [docs/VISION.md](docs/VISION.md) for the idea
and design rules.

> Screenshots: _TODO_

## Install

Arch Linux with Plasma 6 on Wayland.

```sh
git clone https://github.com/mmaachado/dotfiles.git ~/.dotfiles
cd ~/.dotfiles
./install.sh all          # packages → links → wallpapers folder → zsh → KShell
```

`install.sh` installs Python, Typer and Rich if they're missing, then runs
`install.py`. Every changing command accepts `--dry-run`.

| Command | What it does |
|---|---|
| `./install.py check` | Report packages, links, login shell and KShell status (changes nothing) |
| `./install.py packages [-g core -g kshell] [--optional]` | Install missing packages (pacman; AUR via paru/yay) |
| `./install.py link [--force]` | Symlink `home/*` into `$HOME`; existing files go to `~/.local/state/dotfiles/backup/<time>/` |
| `./install.py unlink [--restore]` | Remove the symlinks, optionally restoring the latest backup |
| `./install.py shell` | Make zsh the login shell |
| `./install.py kshell enable\|disable` | Swap between KShell and the Plasma panels |
| `./install.py all [-y] [--optional]` | All of the above, in order |

Packages and linked paths live in [`dotfiles.toml`](dotfiles.toml).

## Layout

```
home/                         mirrors $HOME (each entry in dotfiles.toml is symlinked)
├── .zshrc  .zprofile
├── .config/zsh/              options, aliases, functions
├── .config/quickshell/kshell KShell (QML) + KWin bridge
├── .config/starship.toml  .config/fastfetch/
└── .local/bin/               kshell, pacman_updates
installer/                    install.py internals
```

## KShell keybindings

| Keys | Action |
|---|---|
| Meta / Meta+Space | App launcher |
| Meta+W | Wallpaper picker (images from `~/Pictures/Wallpapers`) |
| Meta+Alt+D | Dashboard (or hover the notch at the top) |
| Meta+O | KWin Overview (moved from Meta+W) |
| Meta+L | Lock screen |

Rebind them in System Settings → Shortcuts → KWin ("KShell: …").
KShell follows your KDE colour scheme, accent colour, icons and animation speed.

## Undo

```sh
./install.py kshell disable     # Plasma panels and default shortcuts come back
./install.py unlink --restore   # put back the files that were replaced
```
