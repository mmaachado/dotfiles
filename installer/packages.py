"""pacman / AUR queries and installs."""

from __future__ import annotations

import shutil
import subprocess

from .system import run


def installed(pkgs: list[str] | tuple[str, ...]) -> set[str]:
    """Which of `pkgs` are installed (by name or as a provided package)."""
    if not pkgs:
        return set()
    # `pacman -T` prints the deps that are NOT satisfied; it also honours provides.
    res = subprocess.run(["pacman", "-T", *pkgs], capture_output=True, text=True)
    missing = set(res.stdout.split())
    return set(pkgs) - missing


def missing(pkgs: list[str] | tuple[str, ...]) -> list[str]:
    have = installed(pkgs)
    return [p for p in pkgs if p not in have]


def aur_helper() -> str | None:
    for helper in ("paru", "yay"):
        if shutil.which(helper):
            return helper
    return None


def install(repo: list[str], aur: list[str], dry_run: bool) -> bool:
    """Install missing packages. Returns False if something could not be installed."""
    ok = True
    if repo:
        ok &= run(["sudo", "pacman", "-S", "--needed", *repo], dry_run) == 0
    if aur:
        helper = aur_helper()
        if helper is None:
            print(f"No AUR helper (paru/yay) found; skipping AUR packages: {', '.join(aur)}")
            return False
        ok &= run([helper, "-S", "--needed", *aur], dry_run) == 0
    return ok
