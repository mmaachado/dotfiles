#!/bin/sh
# Bootstrap: make sure Python, Typer and Rich are installed, then run install.py.
#   ./install.sh all        full setup
#   ./install.sh --help     every command
set -eu
cd "$(dirname "$0")"

if [ ! -f /etc/arch-release ]; then
    echo "This installer targets Arch Linux." >&2
    exit 1
fi

missing=""
for pkg in python python-typer python-rich; do
    pacman -Q "$pkg" >/dev/null 2>&1 || missing="$missing $pkg"
done
if [ -n "$missing" ]; then
    echo ":: Installing installer dependencies:$missing"
    # shellcheck disable=SC2086
    sudo pacman -S --needed $missing
fi

exec python3 install.py "$@"
