#!/usr/bin/env python3
from __future__ import annotations

from typing import Annotated, Optional

import typer

from installer import links as L
from installer import packages as P
from installer import system as S
from installer.manifest import HOME_TREE, ManifestError, load
from installer.ui import BAD, OK, WARN, confirm, console, mark, step, table

app = typer.Typer(help=__doc__, no_args_is_help=True, add_completion=False,
                  rich_markup_mode="rich")
kshell_app = typer.Typer(help="Switch between KShell and the Plasma panels.", no_args_is_help=True)
app.add_typer(kshell_app, name="kshell")

dry_run = Annotated[bool, typer.Option("--dry-run", "-n", help="Show what would happen, change nothing.")]
groups = Annotated[Optional[list[str]], typer.Option("--group", "-g", help="Package group(s) from dotfiles.toml.")]
with_optional = Annotated[bool, typer.Option("--optional", help="Include optional package groups.")]
yes = Annotated[bool, typer.Option("--yes", "-y", help="Don't ask for confirmation.")]


def manifest():
    try:
        return load()
    except ManifestError as e:
        console.print(f"{BAD} {e}")
        raise typer.Exit(2)


@app.command()
def check() -> None:
    m = manifest()
    problems = 0

    t = table("System")
    desktop, kind = S.session()
    plasma = S.plasma_version()
    helper = P.aur_helper()
    t.add_row(mark(S.is_arch()), "Arch Linux", "yes" if S.is_arch() else "no")
    t.add_row(mark(S.is_plasma_wayland()), "Session", f"{desktop or '?'} / {kind or '?'}")
    t.add_row(mark(bool(plasma and plasma.startswith("6"))), "Plasma", plasma or "not installed")
    t.add_row(mark(helper is not None, warn_only=True), "AUR helper", helper or "none (only needed for AUR packages)")
    console.print(t)
    problems += (not S.is_arch()) + (not S.is_plasma_wayland())

    t = table("Packages")
    for g in m.groups.values():
        miss = P.missing(g.repo + g.aur)
        label = g.name + (" (optional)" if g.optional and g.name != "optional" else "")
        t.add_row(mark(not miss, warn_only=g.optional), label,
                  "all installed" if not miss else "missing: " + ", ".join(miss))
        problems += bool(miss) and not g.optional
    console.print(t)

    t = table("Links")
    style = {L.Status.OK: OK, L.Status.MISSING: BAD, L.Status.CONFLICT: BAD, L.Status.FOREIGN: WARN}
    for link in L.plan(m.links):
        t.add_row(style[link.status], f"~/{link.rel}", link.status.value)
        problems += link.status is not L.Status.OK
    console.print(t)

    t = table("Desktop")
    shell = S.login_shell()
    t.add_row(mark(shell.endswith("/zsh")), "Login shell", shell)
    t.add_row(mark(m.wallpapers.is_dir(), warn_only=True), "Wallpapers", str(m.wallpapers))
    t.add_row(mark(S.kshell_running(), warn_only=True), "KShell", "running" if S.kshell_running() else "not running")
    console.print(t)
    problems += not shell.endswith("/zsh")

    if problems:
        console.print(f"\n{BAD} {problems} issue(s). Run [bold]./install.py all[/] to fix them.")
        raise typer.Exit(1)
    console.print(f"\n{OK} Everything is in place.")


@app.command()
def packages(group: groups = None, optional: with_optional = False, dry_run: dry_run = False) -> None:
    m = manifest()
    try:
        groups = m.selected(group, optional)
    except ManifestError as e:
        console.print(f"{BAD} {e}")
        raise typer.Exit(2)
    repo = [p for g in groups for p in P.missing(g.repo)]
    aur = [p for g in groups for p in P.missing(g.aur)]
    if not repo and not aur:
        console.print(f"{OK} Packages already installed ({', '.join(g.name for g in groups)}).")
        return
    if not P.install(repo, aur, dry_run):
        raise typer.Exit(1)


@app.command()
def link(force: Annotated[bool, typer.Option(help="Also replace symlinks that point elsewhere.")] = False,
         dry_run: dry_run = False) -> None:
    plan = L.plan(manifest().links)
    if all(l.status is L.Status.OK for l in plan):
        console.print(f"{OK} All {len(plan)} links already in place.")
        return
    skipped = L.apply(plan, force, dry_run)
    for rel in skipped:
        console.print(f"{WARN} ~/{rel} is a symlink to somewhere else; use --force to replace it.")
    if not dry_run:
        console.print(f"{OK} Linked. Backups (if any) are in {L.BACKUPS}.")


@app.command()
def unlink(restore: Annotated[bool, typer.Option(help="Put back the files from the latest backup.")] = False,
           dry_run: dry_run = False) -> None:
    L.remove(L.plan(manifest().links), restore, dry_run)


@app.command()
def shell(dry_run: dry_run = False) -> None:
    if S.login_shell().endswith("/zsh"):
        console.print(f"{OK} Login shell is already zsh.")
        return
    if not S.set_login_shell("zsh", dry_run):
        raise typer.Exit(1)
    console.print(f"{OK} Log out and back in to use zsh everywhere.")


@kshell_app.command("enable")
def kshell_enable(dry_run: dry_run = False) -> None:
    if not S.kshell("enable", dry_run):
        raise typer.Exit(1)


@kshell_app.command("disable")
def kshell_disable(dry_run: dry_run = False) -> None:
    if not S.kshell("disable", dry_run):
        raise typer.Exit(1)


@app.command(name="all")
def install_all(yes: yes = False, optional: with_optional = False, dry_run: dry_run = False) -> None:
    m = manifest()

    step("Packages")
    if confirm("Install missing packages?", yes or dry_run):
        packages(group=None, optional=optional, dry_run=dry_run)

    step("Links")
    link(force=False, dry_run=dry_run)

    step("Wallpapers")
    if m.wallpapers.is_dir():
        console.print(f"{OK} {m.wallpapers} exists.")
    else:
        console.print(f"  mkdir {m.wallpapers}")
        if not dry_run:
            m.wallpapers.mkdir(parents=True)

    step("Login shell")
    if S.login_shell().endswith("/zsh"):
        console.print(f"{OK} Already zsh.")
    elif confirm("Make zsh your login shell?", yes or dry_run):
        shell(dry_run=dry_run)

    step("KShell")
    if not S.is_plasma_wayland():
        console.print(f"{WARN} Not in a Plasma Wayland session; run [bold]./install.py kshell enable[/] from one.")
    elif confirm("Replace the Plasma panels with KShell?", yes or dry_run):
        kshell_enable(dry_run=dry_run)

    console.print(f"\n{OK} Done. Run [bold]./install.py check[/] to verify.")


if __name__ == "__main__":
    app()
