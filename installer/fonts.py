"""Fonts droid downloads itself into ~/.local/share/fonts/droid."""

from __future__ import annotations

import hashlib
import shutil
import tempfile
import urllib.request
from pathlib import Path

from .manifest import Font, FontFile

DEST = Path.home() / ".local/share/fonts/droid"


def _sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1 << 16), b""):
            h.update(chunk)
    return h.hexdigest()


def _ok(file: FontFile) -> bool:
    path = DEST / file.name
    return path.is_file() and _sha256(path) == file.sha256


def installed(font: Font) -> bool:
    return all(_ok(f) for f in font.files)


def install(font: Font, dry_run: bool) -> None:
    """Download the font's missing files, checking each one's sha256.

    Raises ValueError on a checksum mismatch (nothing is written then).
    """
    for file in font.files:
        if _ok(file):
            continue
        print(f"  fetch   {file.name}")
        if dry_run:
            continue
        DEST.mkdir(parents=True, exist_ok=True)
        req = urllib.request.Request(file.url, headers={"User-Agent": "droid-installer"})
        with tempfile.NamedTemporaryFile(dir=DEST, delete=False) as tmp:
            tmp_path = Path(tmp.name)
            with urllib.request.urlopen(req, timeout=60) as r:
                shutil.copyfileobj(r, tmp)
        got = _sha256(tmp_path)
        if got != file.sha256:
            tmp_path.unlink()
            raise ValueError(f"{file.name}: sha256 {got} doesn't match droid.toml ({file.sha256})")
        tmp_path.chmod(0o644)
        tmp_path.replace(DEST / file.name)
