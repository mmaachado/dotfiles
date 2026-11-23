# droid's tasks. `just` lists them; CI runs the same recipes.

set shell := ["bash", "-euo", "pipefail", "-c"]

kshell := "home/.config/quickshell/kshell"
daemon := kshell / "daemon"
shaders := kshell / "shaders"
qsb := "/usr/lib/qt6/bin/qsb"

# List the recipes
default:
    @just --list --unsorted

# ── Checks ──────────────────────────────────────────────────────────

# Every check CI runs
lint: lint-rust lint-python lint-shell lint-config

# kshelld: formatting and clippy (warnings are errors)
lint-rust:
    cd {{daemon}} && cargo fmt --check
    cd {{daemon}} && cargo clippy --locked --all-targets -- -D warnings

# install.py, the installer package and scripts/
lint-python:
    ruff check installer install.py scripts

# Shell scripts: shellcheck for bash, `zsh -n` for zsh
lint-shell:
    shellcheck install.sh home/.local/bin/kshell
    zsh -n home/.local/bin/pacman_updates
    zsh -n home/.zshrc
    zsh -n home/.zprofile

# droid.toml is valid and agrees with kshelld; config JSON parses
lint-config:
    python3 scripts/check_manifest.py
    for f in {{kshell}}/config/*.json; do python3 -m json.tool "$f" > /dev/null || { echo "invalid JSON: $f"; exit 1; }; done

# kshelld's tests
test:
    cd {{daemon}} && cargo test --locked

# ── Build and run ───────────────────────────────────────────────────

# Build and install kshelld into ~/.local/bin
build:
    home/.local/bin/kshell build

# Recompile the wallpaper transition shaders (.frag → .frag.qsb)
shaders:
    for f in {{shaders}}/*.frag; do {{qsb}} --qt6 -o "$f.qsb" "$f"; done

# Fail if a committed .qsb is older than a fresh compile
shaders-check: shaders
    git diff --exit-code --stat -- {{shaders}}

# Restart KShell
restart:
    home/.local/bin/kshell restart

# Warnings and errors from KShell's latest log
log:
    qs log "$(ls -t /run/user/$(id -u)/quickshell/by-id/*/log.qslog | head -1)" | grep -iE 'warn|error|caused' || echo "No warnings or errors."
