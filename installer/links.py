"""Symlink home/<path> into $HOME, backing up whatever was there."""

from __future__ import annotations

import shutil
import time
from dataclasses import dataclass
from enum import Enum
from pathlib import Path

from .manifest import HOME_TREE

STATE = Path.home() / ".local/state/dotfiles"
BACKUPS = STATE / "backup"


class Status(str, Enum):
    OK = "ok"              # already links to this repo
    MISSING = "missing"    # nothing there
    CONFLICT = "conflict"  # a real file/dir is in the way
    FOREIGN = "foreign"    # a symlink pointing somewhere else


@dataclass(frozen=True)
class Link:
    rel: str
    src: Path
    dst: Path
    status: Status


def plan(paths: tuple[str, ...], home: Path | None = None) -> list[Link]:
    home = home or Path.home()
    out = []
    for rel in paths:
        src, dst = HOME_TREE / rel, home / rel
        if dst.is_symlink():
            status = Status.OK if dst.resolve() == src.resolve() else Status.FOREIGN
        elif dst.exists():
            status = Status.CONFLICT
        else:
            status = Status.MISSING
        out.append(Link(rel, src, dst, status))
    return out


def new_backup_dir() -> Path:
    return BACKUPS / time.strftime("%Y%m%d-%H%M%S")


def latest_backup() -> Path | None:
    dirs = sorted(p for p in BACKUPS.glob("*") if p.is_dir()) if BACKUPS.exists() else []
    return dirs[-1] if dirs else None


def _move_to_backup(link: Link, backup: Path, dry_run: bool) -> None:
    target = backup / link.rel
    print(f"  backup  ~/{link.rel} -> {target}")
    if not dry_run:
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(link.dst, target)


def apply(links: list[Link], force: bool, dry_run: bool) -> list[str]:
    """Create the links. Returns the paths that were skipped (foreign links without --force)."""
    backup = new_backup_dir()
    skipped = []
    for link in links:
        if link.status is Status.OK:
            continue
        if link.status is Status.FOREIGN and not force:
            skipped.append(link.rel)
            continue
        if link.status in (Status.CONFLICT, Status.FOREIGN):
            _move_to_backup(link, backup, dry_run)
        print(f"  link    ~/{link.rel} -> {link.src}")
        if not dry_run:
            link.dst.parent.mkdir(parents=True, exist_ok=True)
            link.dst.symlink_to(link.src, target_is_directory=link.src.is_dir())
    return skipped


def remove(links: list[Link], restore: bool, dry_run: bool) -> None:
    backup = latest_backup() if restore else None
    for link in links:
        if link.status is not Status.OK:
            continue
        print(f"  unlink  ~/{link.rel}")
        if not dry_run:
            link.dst.unlink()
        saved = backup / link.rel if backup else None
        if saved and (saved.exists() or saved.is_symlink()):
            print(f"  restore ~/{link.rel} <- {saved}")
            if not dry_run:
                shutil.move(saved, link.dst)
