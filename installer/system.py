"""Session checks and system-level actions (login shell, KShell)."""

from __future__ import annotations

import os
import pwd
import shlex
import shutil
import subprocess
from pathlib import Path

from .manifest import HOME_TREE

KSHELL = HOME_TREE / ".local/bin/kshell"


def run(cmd: list[str], dry_run: bool = False) -> int:
    """Run a command, echoing it first. In dry-run mode only echo."""
    print(("[dry-run] " if dry_run else "$ ") + shlex.join(cmd))
    if dry_run:
        return 0
    return subprocess.run(cmd).returncode


def is_arch() -> bool:
    return Path("/etc/arch-release").exists()


def session() -> tuple[str, str]:
    return os.environ.get("XDG_CURRENT_DESKTOP", ""), os.environ.get("XDG_SESSION_TYPE", "")


def is_plasma_wayland() -> bool:
    desktop, kind = session()
    return "KDE" in desktop.split(":") and kind == "wayland"


def plasma_version() -> str | None:
    if not shutil.which("plasmashell"):
        return None
    out = subprocess.run(["plasmashell", "--version"], capture_output=True, text=True).stdout
    return out.split()[-1] if out.strip() else None


def login_shell() -> str:
    return pwd.getpwuid(os.getuid()).pw_shell


def set_login_shell(name: str, dry_run: bool) -> bool:
    path = shutil.which(name)
    if path is None:
        print(f"{name} is not installed")
        return False
    if path not in Path("/etc/shells").read_text().split():
        print(f"{path} is not listed in /etc/shells")
        return False
    return run(["chsh", "-s", path], dry_run) == 0


def kshell_running() -> bool:
    res = subprocess.run(["pgrep", "-u", str(os.getuid()), "-f", r"(qs|quickshell) -c kshell"],
                         capture_output=True)
    return res.returncode == 0


def kshell(action: str, dry_run: bool) -> bool:
    return run([str(KSHELL), action], dry_run) == 0
