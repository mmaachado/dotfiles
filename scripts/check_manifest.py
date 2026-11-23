#!/usr/bin/env python3
"""Check droid.toml: [release] is complete, kshelld's version matches, linked paths exist."""

from __future__ import annotations

import sys
import tomllib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CARGO = ROOT / "home/.config/quickshell/kshell/daemon/Cargo.toml"


def main() -> int:
    droid = tomllib.loads((ROOT / "droid.toml").read_text())
    release = droid.get("release", {})
    problems = [f"[release] is missing {k}" for k in ("name", "version", "codename") if not release.get(k)]
    cargo = tomllib.loads(CARGO.read_text())["package"]["version"]
    if cargo != release.get("version"):
        problems.append(f"kshelld is {cargo}, droid.toml says {release.get('version')}")
    problems += [f"linked path missing: home/{rel}" for rel in droid.get("links", {}).get("paths", [])
                 if not (ROOT / "home" / rel).exists()]
    for p in problems:
        print(p, file=sys.stderr)
    if not problems:
        print(f"{release['name']} {release['version']} ({release['codename']})")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
