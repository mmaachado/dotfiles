"""Load and validate droid.toml."""

from __future__ import annotations

import tomllib
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
HOME_TREE = ROOT / "home"
MANIFEST = ROOT / "droid.toml"


class ManifestError(Exception):
    pass


@dataclass(frozen=True)
class Release:
    name: str
    version: str
    codename: str
    description: str

    def __str__(self) -> str:
        return f"{self.name} {self.version} ({self.codename})"


@dataclass(frozen=True)
class Group:
    name: str
    description: str
    repo: tuple[str, ...]
    aur: tuple[str, ...]
    optional: bool


@dataclass(frozen=True)
class Manifest:
    release: Release
    groups: dict[str, Group]
    links: tuple[str, ...]
    wallpapers: Path

    def selected(self, names: list[str] | None, include_optional: bool) -> list[Group]:
        """Groups to act on: the named ones, or every required group (+ optional)."""
        if names:
            unknown = sorted(set(names) - self.groups.keys())
            if unknown:
                raise ManifestError(f"unknown package group(s): {', '.join(unknown)}")
            return [self.groups[n] for n in names]
        return [g for g in self.groups.values() if include_optional or not g.optional]


def load(path: Path = MANIFEST) -> Manifest:
    try:
        data = tomllib.loads(path.read_text())
    except (OSError, tomllib.TOMLDecodeError) as e:
        raise ManifestError(f"cannot read {path}: {e}") from e

    rel = data.get("release", {})
    missing = [k for k in ("name", "version", "codename") if not rel.get(k)]
    if missing:
        raise ManifestError(f"[release] is missing: {', '.join(missing)}")
    release = Release(
        name=rel["name"],
        version=rel["version"],
        codename=rel["codename"],
        description=rel.get("description", ""),
    )

    groups = {
        name: Group(
            name=name,
            description=g.get("description", ""),
            repo=tuple(g.get("repo", [])),
            aur=tuple(g.get("aur", [])),
            optional=bool(g.get("optional", False)),
        )
        for name, g in data.get("packages", {}).items()
    }

    links = tuple(data.get("links", {}).get("paths", []))
    for rel in links:
        p = Path(rel)
        if p.is_absolute() or ".." in p.parts:
            raise ManifestError(f"link path must be relative to home/: {rel}")
        if not (HOME_TREE / p).exists():
            raise ManifestError(f"link source missing in repo: home/{rel}")

    wallpapers = Path(data.get("wallpapers", {}).get("dir", "~/Pictures/Wallpapers")).expanduser()
    return Manifest(release=release, groups=groups, links=links, wallpapers=wallpapers)
